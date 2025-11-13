import json
import boto3
import os

# Get region from Lambda context or environment
REGION = os.environ.get('BEDROCK_REGION', os.environ.get('AWS_REGION', 'eu-central-1'))
bedrock_runtime = boto3.client('bedrock-agent-runtime', region_name=REGION)

def lambda_handler(event, context):
    """
    Lambda function to proxy Bedrock Agent requests
    This allows the frontend to call Bedrock without needing AWS credentials
    """
    
    # Handle CORS
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Content-Type': 'application/json'
    }
    
    # Handle preflight
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': headers,
            'body': ''
        }
    
    try:
        # Parse request body
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event.get('body', {})
        
        agent_id = body.get('agentId') or os.environ.get('AGENT_ID')
        agent_alias_id = body.get('agentAliasId') or os.environ.get('AGENT_ALIAS_ID')
        session_id = body.get('sessionId', 'web-session')
        question = body.get('question', '')
        
        if not question:
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'Question is required'})
            }
        
        if not agent_id or not agent_alias_id:
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'Agent ID and Alias ID are required'})
            }
        
        # Call Bedrock Agent
        response = bedrock_runtime.invoke_agent(
            agentId=agent_id,
            agentAliasId=agent_alias_id,
            sessionId=session_id,
            inputText=question,
            enableTrace=False
        )
        
        # Read streaming response
        agent_response = ''
        event_stream = response.get('completion')
        
        if event_stream:
            import base64
            for event in event_stream:
                if 'chunk' in event:
                    chunk = event['chunk']
                    if 'bytes' in chunk:
                        try:
                            # Decode base64 - handle padding issues
                            bytes_data = str(chunk['bytes'])  # Ensure it's a string
                            
                            # Remove any whitespace
                            bytes_data = bytes_data.strip()
                            
                            # Add padding if needed (base64 strings must be multiple of 4)
                            missing_padding = len(bytes_data) % 4
                            if missing_padding:
                                bytes_data += '=' * (4 - missing_padding)
                            
                            # Decode base64
                            try:
                                decoded_bytes = base64.b64decode(bytes_data, validate=True)
                                decoded = decoded_bytes.decode('utf-8')
                                
                                # Try to parse as JSON
                                try:
                                    parsed = json.loads(decoded)
                                    if isinstance(parsed, dict):
                                        if 'text' in parsed:
                                            agent_response += parsed['text']
                                        elif 'completion' in parsed:
                                            agent_response += parsed['completion']
                                        else:
                                            # Try to find any string value
                                            for key, value in parsed.items():
                                                if isinstance(value, str) and value.strip():
                                                    agent_response += value
                                                    break
                                    else:
                                        agent_response += str(parsed)
                                except json.JSONDecodeError:
                                    # If not JSON, use the decoded string directly
                                    agent_response += decoded
                            except Exception as decode_error:
                                print(f"Base64 decode error: {decode_error}, data length: {len(bytes_data)}")
                                # Try without validation
                                try:
                                    decoded_bytes = base64.b64decode(bytes_data, validate=False)
                                    decoded = decoded_bytes.decode('utf-8', errors='ignore')
                                    agent_response += decoded
                                except:
                                    pass
                        except Exception as e:
                            # If base64 decode fails, try to get text directly
                            print(f"Error processing chunk: {e}")
                            if 'text' in chunk:
                                agent_response += str(chunk['text'])
                    elif 'text' in chunk:
                        # Direct text response
                        agent_response += str(chunk['text'])
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'response': agent_response or 'No response received',
                'sessionId': session_id
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({
                'error': str(e),
                'type': type(e).__name__
            })
        }

