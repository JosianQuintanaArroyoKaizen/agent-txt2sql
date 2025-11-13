from boto3.session import Session
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
from botocore.credentials import Credentials
import json
import os
from requests import request
import base64
import io
import sys

#For this to run on a local machine in VScode, you need to set the AWS_PROFILE environment variable to the name of the profile/credentials you want to use. 
#You also need to input your model ID near the bottom of this file.

#check for credentials
#echo $AWS_ACCESS_KEY_ID
#echo $AWS_SECRET_ACCESS_KEY
#echo $AWS_SESSION_TOKEN
#os.environ["AWS_PROFILE"] = "agent-demo"

# Get configuration from environment variables (for App Runner) or use defaults
agentId = os.environ.get("AGENT_ID", "<YOUR AGENT ID>")  # Set via environment variable in App Runner
agentAliasId = os.environ.get("AGENT_ALIAS_ID", "<YOUR ALIAS ID>")  # Set via environment variable in App Runner

theRegion = os.environ.get("AWS_REGION", "eu-central-1")  # Default to eu-central-1
os.environ["AWS_REGION"] = theRegion
region = os.environ.get("AWS_REGION")
llm_response = ""

def sigv4_request(
    url,
    method='GET',
    body=None,
    params=None,
    headers=None,
    service='execute-api',
    region=os.environ['AWS_REGION'],
    credentials=Session().get_credentials().get_frozen_credentials()
):
    """Sends an HTTP request signed with SigV4
    Args:
    url: The request URL (e.g. 'https://www.example.com').
    method: The request method (e.g. 'GET', 'POST', 'PUT', 'DELETE'). Defaults to 'GET'.
    body: The request body (e.g. json.dumps({ 'foo': 'bar' })). Defaults to None.
    params: The request query params (e.g. { 'foo': 'bar' }). Defaults to None.
    headers: The request headers (e.g. { 'content-type': 'application/json' }). Defaults to None.
    service: The AWS service name. Defaults to 'execute-api'.
    region: The AWS region id. Defaults to the env var 'AWS_REGION'.
    credentials: The AWS credentials. Defaults to the current boto3 session's credentials.
    Returns:
     The HTTP response
    """

    # sign request
    req = AWSRequest(
        method=method,
        url=url,
        data=body,
        params=params,
        headers=headers
    )
    SigV4Auth(credentials, service, region).add_auth(req)
    req = req.prepare()

    # send request
    return request(
        method=req.method,
        url=req.url,
        headers=req.headers,
        data=req.body
    )
    
    

def askQuestion(question, url, endSession=False):
    myobj = {
        "inputText": question,   
        "enableTrace": True,
        "endSession": endSession
    }
    
    try:
        # send request
        response = sigv4_request(
            url,
            method='POST',
            service='bedrock',
            headers={
                'content-type': 'application/json', 
                'accept': 'application/json',
            },
            region=theRegion,
            body=json.dumps(myobj)
        )
        
        return decode_response(response)
    except Exception as e:
        error_msg = f"Error making request to Bedrock agent: {str(e)}"
        print(error_msg)
        return error_msg, error_msg




def decode_response(response):
    # Check HTTP status code first
    if not hasattr(response, 'status_code'):
        error_msg = f"Invalid response object: {type(response)}"
        return error_msg, f"Error: {error_msg}"
    
    if response.status_code != 200:
        error_text = ""
        try:
            error_text = response.text
        except:
            error_text = "Unable to read error message"
        error_msg = f"HTTP Error {response.status_code}: {error_text}"
        return error_msg, f"Error: {error_msg}"
    
    # Create a StringIO object to capture print statements
    captured_output = io.StringIO()
    sys.stdout = captured_output

    # Your existing logic - try to read the response
    string = ""
    try:
        # First try to use iter_content for streaming responses
        if hasattr(response, 'iter_content'):
            for line in response.iter_content(chunk_size=None):
                try:
                    if isinstance(line, bytes):
                        string += line.decode(encoding='utf-8')
                    else:
                        string += str(line)
                except:
                    continue
        # Fallback to response.text if iter_content is not available or fails
        if not string and hasattr(response, 'text'):
            string = response.text
        # Last fallback to response.content
        if not string and hasattr(response, 'content'):
            try:
                string = response.content.decode('utf-8')
            except:
                string = str(response.content)
    except Exception as e:
        error_msg = f"Error reading response: {str(e)}"
        sys.stdout = sys.__stdout__
        return error_msg, error_msg

    print("=" * 80)
    print("RAW RESPONSE FROM BEDROCK (first 2000 chars):")
    print(string[:2000] if string else "EMPTY")
    print("=" * 80)
    
    # Check if response is empty
    if not string or len(string.strip()) == 0:
        error_msg = "Empty response received from Bedrock agent"
        sys.stdout = sys.__stdout__
        return error_msg, error_msg
    
    final_response = ""
    llm_response = ""
    
    try:
        split_response = string.split(":message-type")
        print(f"Split Response: {split_response}")
        print(f"length of split: {len(split_response)}")

        # Try to find final response in bytes format
        for idx in range(len(split_response)):
            if "bytes" in split_response[idx]:
                try:
                    parts = split_response[idx].split("\"")
                    if len(parts) > 3:
                        encoded_last_response = parts[3]
                        decoded = base64.b64decode(encoded_last_response)
                        final_response = decoded.decode('utf-8')
                        print(f"Found response in bytes format: {final_response}")
                        break
                except Exception as e:
                    print(f"Error decoding bytes at index {idx}: {e}")
                    continue
            else:
                print(f"no bytes at index {idx}")
                print(split_response[idx])
        
        # If not found in bytes format, try to find in finalResponse format
        if not final_response:
            last_response = split_response[-1]
            print(f"Last Response: {last_response}")
            if "bytes" in last_response:
                try:
                    print("Bytes in last response")
                    parts = last_response.split("\"")
                    if len(parts) > 3:
                        encoded_last_response = parts[3]
                        decoded = base64.b64decode(encoded_last_response)
                        final_response = decoded.decode('utf-8')
                except Exception as e:
                    print(f"Error decoding bytes in last response: {e}")
            else:
                print("no bytes in last response, trying finalResponse format")
                try:
                    final_response_idx = string.find('finalResponse')
                    if final_response_idx != -1:
                        part1 = string[final_response_idx + len('finalResponse":'):] 
                        part2_end = part1.find('"}')
                        if part2_end != -1:
                            part2 = part1[:part2_end + 2]
                            if part2 and part2.strip():
                                try:
                                    parsed = json.loads(part2)
                                    if 'text' in parsed:
                                        final_response = parsed['text']
                                    else:
                                        # Try to get the response text from other possible keys
                                        final_response = str(parsed)
                                except json.JSONDecodeError as je:
                                    print(f"JSON decode error parsing part2: {je}, part2: {part2[:100]}")
                                    final_response = string  # Fallback to raw string
                            else:
                                final_response = string  # Fallback to raw string
                        else:
                            # Try to parse the entire response as JSON
                            try:
                                if string and string.strip():
                                    parsed = json.loads(string)
                                    if 'finalResponse' in parsed and 'text' in parsed['finalResponse']:
                                        final_response = parsed['finalResponse']['text']
                            except json.JSONDecodeError as je:
                                print(f"JSON decode error parsing full string: {je}")
                                pass
                            except Exception as e:
                                print(f"Error parsing full string: {e}")
                                pass
                    else:
                        # Try parsing the entire string as JSON
                        try:
                            # Check if string is empty before parsing
                            if not string or not string.strip():
                                final_response = "No response content received from agent"
                            else:
                                parsed = json.loads(string)
                                # Look for common response patterns
                                if isinstance(parsed, dict):
                                    if 'completion' in parsed:
                                        final_response = parsed['completion']
                                    elif 'output' in parsed:
                                        final_response = parsed['output']
                                    elif 'text' in parsed:
                                        final_response = parsed['text']
                                    else:
                                        final_response = str(parsed)
                                else:
                                    final_response = str(parsed)
                        except json.JSONDecodeError as je:
                            # If JSON parsing fails, use the raw string
                            print(f"JSON decode error in decode_response: {je}")
                            final_response = string if string else "No response content received from agent"
                        except Exception as e:
                            # If all parsing fails, use the raw string
                            print(f"Error parsing response as JSON: {e}")
                            final_response = string if string else "No response content received from agent"
                except Exception as e:
                    print(f"Error parsing finalResponse: {e}")
                    final_response = string  # Fallback to raw string
        
        # Clean up the response
        if final_response:
            llm_response = final_response.replace("\"", "")
            llm_response = llm_response.replace("{input:{value:", "")
            llm_response = llm_response.replace(",source:null}}", "")
        else:
            # If we still don't have a response, use the raw string
            llm_response = string if string else "No response received from agent"
        
        print("=" * 80)
        print(f"EXTRACTED final_response length: {len(final_response) if final_response else 0}")
        print(f"EXTRACTED final_response preview: {final_response[:500] if final_response else 'EMPTY'}")
        print(f"EXTRACTED llm_response length: {len(llm_response) if llm_response else 0}")
        print(f"EXTRACTED llm_response preview: {llm_response[:500] if llm_response else 'EMPTY'}")
        print("=" * 80)
            
    except Exception as e:
        error_msg = f"Error parsing response: {str(e)}"
        print(error_msg)
        import traceback
        print(traceback.format_exc())
        llm_response = f"{error_msg}. Raw response: {string[:500]}"  # Include first 500 chars for debugging

    # Restore original stdout
    sys.stdout = sys.__stdout__

    # Get the string from captured output
    captured_string = captured_output.getvalue()
    
    print("=" * 80)
    print(f"RETURNING - captured_string length: {len(captured_string) if captured_string else 0}")
    print(f"RETURNING - llm_response length: {len(llm_response) if llm_response else 0}")
    print(f"RETURNING - llm_response: {llm_response[:200] if llm_response else 'EMPTY'}")
    print("=" * 80)

    # Return both the captured output and the final response
    return captured_string, llm_response


def lambda_handler(event, context):
    
    sessionId = event.get("sessionId", "MYSESSION")
    question = event.get("question", "")
    endSession = False
    
    print(f"Session: {sessionId} asked question: {question}")
    
    # Validate inputs
    if not question:
        return {
            "status_code": 400,
            "body": json.dumps({"error": "No question provided"})
        }
    
    # Check if agent ID and alias are configured
    if agentId == "<YOUR AGENT ID>" or agentAliasId == "<YOUR ALIAS ID>":
        error_msg = "Agent ID or Alias ID not configured. Please set AGENT_ID and AGENT_ALIAS_ID environment variables."
        print(f"ERROR: {error_msg}")
        return {
            "status_code": 500,
            "body": json.dumps({"error": error_msg})
        }
    
    try:
        if event.get("endSession") == "true" or event.get("endSession") == True:
            endSession = True
    except:
        endSession = False
    
    url = f'https://bedrock-agent-runtime.{theRegion}.amazonaws.com/agents/{agentId}/agentAliases/{agentAliasId}/sessions/{sessionId}/text'
    print(f"Calling Bedrock agent at: {url}")

    
    try: 
        # askQuestion returns (captured_string, llm_response)
        # captured_string = trace/debug output
        # llm_response = actual agent response text
        trace_output, agent_response = askQuestion(question, url, endSession)
        
        print("=" * 80)
        print(f"lambda_handler - after askQuestion:")
        print(f"  trace_output type: {type(trace_output)}, length: {len(str(trace_output)) if trace_output else 0}")
        print(f"  trace_output preview: {str(trace_output)[:300] if trace_output else 'EMPTY'}")
        print(f"  agent_response type: {type(agent_response)}, length: {len(str(agent_response)) if agent_response else 0}")
        print(f"  agent_response preview: {str(agent_response)[:300] if agent_response else 'EMPTY'}")
        print("=" * 80)
        
        # Ensure trace_output and agent_response are strings and not empty
        if trace_output is None:
            trace_output = ""
        if agent_response is None:
            agent_response = ""
        
        # Ensure both are strings
        if not isinstance(trace_output, str):
            trace_output = str(trace_output)
        if not isinstance(agent_response, str):
            agent_response = str(agent_response)
        
        # Final check - ensure they're not empty after conversion
        if not trace_output.strip():
            trace_output = "No trace data available"
        if not agent_response.strip():
            agent_response = "No response content received from agent"
        
        # Note: response = trace output, trace_data = actual agent response
        # This matches what the frontend expects
        result = {
            "response": trace_output,  # Debug/trace output goes here
            "trace_data": agent_response  # Actual agent answer goes here
        }
        
        print("=" * 80)
        print(f"lambda_handler - result dict:")
        print(f"  result['response'] length: {len(result['response'])}")
        print(f"  result['trace_data'] length: {len(result['trace_data'])}")
        print("=" * 80)
        
        try:
            body_json = json.dumps(result)
            print(f"Returning response with body length: {len(body_json)}")
            
            # Double-check that body_json is not empty
            if not body_json or not body_json.strip():
                body_json = json.dumps({"error": "Empty response body generated", "response": response, "trace_data": trace_data})
                print("WARNING: Generated empty body, using fallback")
            
            return {
                "status_code": 200,
                "body": body_json
            }
        except Exception as json_error:
            print(f"ERROR serializing response to JSON: {json_error}")
            return {
                "status_code": 500,
                "body": json.dumps({"error": f"Error serializing response: {str(json_error)}", "response_preview": str(response)[:100]})
            }
    except Exception as e:
        error_msg = f"Error in lambda_handler: {str(e)}"
        print(f"ERROR: {error_msg}")
        import traceback
        print(traceback.format_exc())
        
        return {
            "status_code": 500,
            "body": json.dumps({"error": error_msg})
        }


