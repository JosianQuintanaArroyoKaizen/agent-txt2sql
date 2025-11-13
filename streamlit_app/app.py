import invoke_agent as agenthelper
import streamlit as st
import json
import pandas as pd
from PIL import Image, ImageOps, ImageDraw
import traceback
import sys

# Streamlit page configuration
st.set_page_config(page_title="Text2SQL Agent", page_icon=":robot_face:", layout="wide")

# Function to crop image into a circle
def crop_to_circle(image):
    mask = Image.new('L', image.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse((0, 0) + image.size, fill=255)
    result = ImageOps.fit(image, mask.size, centering=(0.5, 0.5))
    result.putalpha(mask)
    return result

# Title
st.title("Text2SQL Agent - Amazon Athena")

# Display a text box for input
prompt = st.text_input("Please enter your query?", max_chars=2000)
prompt = prompt.strip()

# Display a primary button for submission
submit_button = st.button("Submit", type="primary")

# Display a button to end the session
end_session_button = st.button("End Session")

# Sidebar for user input
st.sidebar.title("Trace Data")




# Session State Management
if 'history' not in st.session_state:
    st.session_state['history'] = []

# Function to parse and format response
def format_response(response_body):
    # Handle None or empty input
    if response_body is None:
        return "..."
    
    # If it's already a DataFrame, return it
    if isinstance(response_body, pd.DataFrame):
        return response_body
    
    # Convert to string if not already
    if not isinstance(response_body, str):
        response_body = str(response_body)
    
    # Handle empty string
    if not response_body.strip():
        return "..."
    
    try:
        # Try to load the response as JSON
        data = json.loads(response_body)
        # If it's a list, convert it to a DataFrame for better visualization
        if isinstance(data, list):
            return pd.DataFrame(data)
        else:
            return response_body
    except json.JSONDecodeError:
        # If response is not JSON, return as is
        return response_body
    except Exception as e:
        # Catch any other errors
        return f"Error formatting response: {str(e)}"



# Handling user input and responses
if submit_button and prompt:
    # Wrap everything in a try-except to catch ALL errors
    try:
        # Initialize variables
        response = None
        response_data = None
        
        # Log to console AND display
        st.write("🔄 Processing your question...")
        st.write(f"📝 Question: {prompt}")
        
        event = {
            "sessionId": "MYSESSION",
            "question": prompt
        }
        
        # Log to stderr for server logs
        print("=" * 50, file=sys.stderr)
        print(f"Processing question: {prompt}", file=sys.stderr)
        print(f"Event: {event}", file=sys.stderr)
        
        try:
            response = agenthelper.lambda_handler(event, None)
            print(f"Response received: {response}", file=sys.stderr)
            st.write("🔍 Debug: Response received", response)  # Debug output
        except Exception as e:
            error_msg = f"Error calling agent: {str(e)}"
            print(f"ERROR in lambda_handler: {error_msg}", file=sys.stderr)
            import traceback
            print(traceback.format_exc(), file=sys.stderr)
            st.error(error_msg)
            st.exception(e)  # Show full traceback
            response = None
            raise  # Re-raise to be caught by outer try-except
        
        # Debug: Show response structure
        if response:
            st.write("🔍 Debug: Response type:", type(response))
            st.write("🔍 Debug: Response keys:", list(response.keys()) if isinstance(response, dict) else "Not a dict")
            if isinstance(response, dict) and 'body' in response:
                st.write("🔍 Debug: Body type:", type(response['body']))
                st.write("🔍 Debug: Body length:", len(str(response['body'])) if response['body'] else 0)
                st.write("🔍 Debug: Body preview:", str(response['body'])[:200] if response['body'] else "Empty")
        
        try:
            # Parse the JSON string
            if response and isinstance(response, dict) and 'body' in response:
                body_content = response['body']
                
                # Handle different body types
                if body_content is None:
                    st.error("❌ Response body is None")
                    st.warning("**Possible causes:**")
                    st.write("1. Bedrock Agent API returned empty response")
                    st.write("2. Check App Runner environment variables (AGENT_ID, AGENT_ALIAS_ID)")
                    st.write("3. Check AWS credentials and permissions")
                    st.write("4. Check CloudWatch logs for App Runner service")
                    response_data = None
                elif isinstance(body_content, str):
                    body_content = body_content.strip()
                    if body_content:
                        try:
                            response_data = json.loads(body_content)
                            st.success("✅ Successfully parsed JSON response")
                        except json.JSONDecodeError as e:
                            error_msg = f"❌ JSON decoding error: {str(e)}\n"
                            error_msg += f"**Body content (first 500 chars):** {body_content[:500]}"
                            st.error(error_msg)
                            st.warning("**This usually means:**")
                            st.write("- Backend returned non-JSON response (HTML error page?)")
                            st.write("- Response was truncated or corrupted")
                            st.write("- Check backend logs for actual error")
                            response_data = None
                    else:
                        st.error("❌ Empty response body string received from agent")
                        st.warning("**Troubleshooting steps:**")
                        st.write("1. **Check App Runner environment variables:**")
                        st.code("aws apprunner describe-service --service-arn <SERVICE_ARN> --region eu-central-1 --query 'Service.SourceConfiguration.ImageRepository.ImageConfiguration.RuntimeEnvironmentVariables'")
                        st.write("2. **Check CloudWatch Logs:**")
                        st.code("aws logs tail /aws/apprunner/<SERVICE_NAME>/<INSTANCE_ID> --follow --region eu-central-1")
                        st.write("3. **Verify Bedrock Agent is accessible:**")
                        st.code("aws bedrock-agent describe-agent --agent-id <AGENT_ID> --region eu-central-1")
                        st.write("4. **Check IAM permissions** for App Runner instance role")
                        response_data = None
                elif isinstance(body_content, dict):
                    # Body is already a dict, use it directly
                    response_data = body_content
                    st.success("✅ Response body is already a dictionary")
                else:
                    st.error(f"Unexpected body type: {type(body_content)}")
                    response_data = None
            else:
                error_msg = "Invalid or empty response received"
                if response:
                    if isinstance(response, dict):
                        error_msg += f". Response keys: {list(response.keys())}"
                    else:
                        error_msg += f". Response type: {type(response)}"
                else:
                    error_msg += ". Response is None"
                st.error(error_msg)
                response_data = None
        except Exception as e:
            error_msg = f"Unexpected error parsing response: {str(e)}"
            st.error(error_msg)
            st.exception(e)
            response_data = None 
        
        try:
            if response_data:
                # Extract the response and trace data
                if 'response' in response_data and 'trace_data' in response_data:
                    all_data = format_response(response_data['response'])
                    the_response = response_data['trace_data']
                elif 'error' in response_data:
                    all_data = "..."
                    the_response = f"Error: {response_data['error']}"
                else:
                    all_data = "..."
                    the_response = f"Unexpected response format. Keys: {list(response_data.keys())}"
            else:
                all_data = "..." 
                the_response = "Apologies, but an error occurred. Please check the error messages above and try again."
        except Exception as e:
            all_data = "..." 
            the_response = f"Error processing response: {str(e)}" 

        # Use trace_data and formatted_response as needed
        st.sidebar.text_area("", value=all_data, height=300)
        st.session_state['history'].append({"question": prompt, "answer": the_response})
        st.session_state['trace_data'] = the_response
        
    except json.JSONDecodeError as e:
        # Specifically catch JSON decode errors
        error_msg = f"JSON Decode Error: {str(e)}"
        print(f"JSON DECODE ERROR: {error_msg}", file=sys.stderr)
        print(f"Error details: {e}", file=sys.stderr)
        print(traceback.format_exc(), file=sys.stderr)
        st.error(f"❌ JSON Parsing Error: {error_msg}")
        st.exception(e)
        st.write("**Debug Info:**")
        st.write(f"- Error message: {str(e)}")
        st.write(f"- Error position: line {e.lineno if hasattr(e, 'lineno') else 'N/A'}, column {e.colno if hasattr(e, 'colno') else 'N/A'}")
        st.write(f"- Response was: {response}")
        # Still add to history so user knows something happened
        st.session_state['history'].append({
            "question": prompt, 
            "answer": f"JSON parsing error: {error_msg}"
        })
    except Exception as e:
        # Catch ANY other error that might occur
        error_msg = f"Unexpected error: {str(e)}"
        error_type = type(e).__name__
        print(f"FATAL ERROR [{error_type}]: {error_msg}", file=sys.stderr)
        print(traceback.format_exc(), file=sys.stderr)
        st.error(f"❌ Error ({error_type}): {error_msg}")
        st.exception(e)
        st.write("**Full Traceback:**")
        st.code(traceback.format_exc())
        # Still add to history so user knows something happened
        st.session_state['history'].append({
            "question": prompt, 
            "answer": f"Error occurred: {error_msg}"
        })

    
    

if end_session_button:
    st.session_state['history'].append({"question": "Session Ended", "answer": "Thank you for using AnyCompany Support Agent!"})
    event = {
        "sessionId": "MYSESSION",
        "question": "placeholder to end session",
        "endSession": True
    }
    agenthelper.lambda_handler(event, None)
    st.session_state['history'].clear()


# Display conversation history
st.write("## Conversation History")

for chat in reversed(st.session_state['history']):
    
    # Creating columns for Question
    col1_q, col2_q = st.columns([2, 10])
    with col1_q:
        human_image = Image.open('/home/ubuntu/app/streamlit_app/human_face.png')
        circular_human_image = crop_to_circle(human_image)
        st.image(circular_human_image, width=125)
    with col2_q:
        st.text_area("Q:", value=chat["question"], height=50, key=str(chat)+"q", disabled=True)

    # Creating columns for Answer
    col1_a, col2_a = st.columns([2, 10])
    if isinstance(chat["answer"], pd.DataFrame):
        with col1_a:
            robot_image = Image.open('/home/ubuntu/app/streamlit_app/robot_face.jpg')
            circular_robot_image = crop_to_circle(robot_image)
            st.image(circular_robot_image, width=100)
        with col2_a:
            st.dataframe(chat["answer"])
    else:
        with col1_a:
            robot_image = Image.open('/home/ubuntu/app/streamlit_app/robot_face.jpg')
            circular_robot_image = crop_to_circle(robot_image)
            st.image(circular_robot_image, width=150)
        with col2_a:
            st.text_area("A:", value=chat["answer"], height=100, key=str(chat)+"a")


# Example Prompts Section


# Increase the maximum width of the text in each cell of the dataframe
pd.set_option('display.max_colwidth', None)

# Define the queries and their descriptions
query_data = {
    "Test Prompts": [
        "Show me all procedures in the imaging category that are insured.",
        "Return to me the number of procedures that are in the laboratory category.",
        "Let me see the number of procedures that are either in the laboratory, imaging, or surgery category, and insured.",
        "Return me information on all customers who have a past due amount over 70.",
        "Provide me details on all customers who are VIP, and have a balance over 300.",
        "Get me data of all procedures that were not insured, with customer names."
    ]
}

# Create DataFrame
queries_df = pd.DataFrame(query_data)

# Display the DataFrame in Streamlit
st.write("## Test Prompts for Amazon Athena")
st.dataframe(queries_df, width=900)  # Adjust the width to fit your layout
