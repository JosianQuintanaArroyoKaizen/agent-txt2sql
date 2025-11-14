#!/usr/bin/env python3
import boto3
import json

# Initialize client
client = boto3.client('bedrock-agent-runtime', region_name='eu-central-1')

# Invoke agent
response = client.invoke_agent(
    agentId='G1RWZFEZ4O',
    agentAliasId='TSTALIASID',
    sessionId='test-session-output-format',
    inputText='Show me 5 incidents with code E_A_C_09',
    enableTrace=False
)

# Read streaming response
agent_response = ''
event_stream = response.get('completion')

for event in event_stream:
    if 'chunk' in event:
        chunk = event['chunk']
        if 'bytes' in chunk:
            chunk_data = json.loads(chunk['bytes'].decode('utf-8'))
            if 'text' in chunk_data:
                agent_response += chunk_data['text']

print("=" * 80)
print("AGENT RESPONSE:")
print("=" * 80)
print(agent_response)
print("=" * 80)
print(f"\nOutput length: {len(agent_response)} characters")
