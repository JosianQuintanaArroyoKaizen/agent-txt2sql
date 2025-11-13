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

    print("Decoded response", string)
    
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
                            parsed = json.loads(part2)
                            if 'text' in parsed:
                                final_response = parsed['text']
                            else:
                                # Try to get the response text from other possible keys
                                final_response = str(parsed)
                        else:
                            # Try to parse the entire response as JSON
                            try:
                                parsed = json.loads(string)
                                if 'finalResponse' in parsed and 'text' in parsed['finalResponse']:
                                    final_response = parsed['finalResponse']['text']
                            except:
                                pass
                    else:
                        # Try parsing the entire string as JSON
                        try:
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
                        except:
                            # If all parsing fails, use the raw string
                            final_response = string
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
            
    except Exception as e:
        error_msg = f"Error parsing response: {str(e)}"
        print(error_msg)
        llm_response = f"{error_msg}. Raw response: {string[:500]}"  # Include first 500 chars for debugging

    # Restore original stdout
    sys.stdout = sys.__stdout__

    # Get the string from captured output
    captured_string = captured_output.getvalue()

    # Return both the captured output and the final response
    return captured_string, llm_response


def lambda_handler(event, context):
    
    sessionId = event["sessionId"]
    question = event["question"]
    endSession = False
    
    print(f"Session: {sessionId} asked question: {question}")
    
    try:
        if (event["endSession"] == "true"):
            endSession = True
    except:
        endSession = False
    
    url = f'https://bedrock-agent-runtime.{theRegion}.amazonaws.com/agents/{agentId}/agentAliases/{agentAliasId}/sessions/{sessionId}/text'

    
    try: 
        response, trace_data = askQuestion(question, url, endSession)
        return {
            "status_code": 200,
            "body": json.dumps({"response": response, "trace_data": trace_data})
        }
    except Exception as e:
        return {
            "status_code": 500,
            "body": json.dumps({"error": str(e)})
        }


