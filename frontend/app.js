// Configuration
let config = {
    agentId: 'G1RWZFEZ4O',
    agentAliasId: 'TSTALIASID',
    awsRegion: 'eu-central-1',
    sessionId: 'web-session-' + Date.now()
};

// Load config from localStorage
function loadConfig() {
    const saved = localStorage.getItem('agentConfig');
    if (saved) {
        config = { ...config, ...JSON.parse(saved) };
    }
    
    document.getElementById('agentId').value = config.agentId;
    document.getElementById('agentAliasId').value = config.agentAliasId;
    document.getElementById('awsRegion').value = config.awsRegion;
}

// Save config to localStorage
function saveConfig() {
    config.agentId = document.getElementById('agentId').value.trim();
    config.agentAliasId = document.getElementById('agentAliasId').value.trim();
    config.awsRegion = document.getElementById('awsRegion').value.trim();
    
    localStorage.setItem('agentConfig', JSON.stringify({
        agentId: config.agentId,
        agentAliasId: config.agentAliasId,
        awsRegion: config.awsRegion
    }));
    
    showStatus('Configuration saved!', 'success');
}

// Load conversation history
function loadHistory() {
    const history = localStorage.getItem('conversationHistory');
    if (history) {
        const messages = JSON.parse(history);
        const messagesDiv = document.getElementById('messages');
        messagesDiv.innerHTML = '';
        messages.forEach(msg => {
            addMessage(msg.text, msg.type);
        });
    }
}

// Save conversation history
function saveHistory() {
    const messages = [];
    document.querySelectorAll('.message').forEach(msg => {
        const text = msg.textContent.replace(/^(Agent|You|Error):\s*/, '');
        const type = msg.classList.contains('user') ? 'user' : 
                    msg.classList.contains('error') ? 'error' : 'agent';
        messages.push({ text, type });
    });
    localStorage.setItem('conversationHistory', JSON.stringify(messages));
}

// Clear conversation history
function clearHistory() {
    if (confirm('Clear conversation history?')) {
        localStorage.removeItem('conversationHistory');
        const messagesDiv = document.getElementById('messages');
        messagesDiv.innerHTML = '<div class="message agent"><strong>Agent:</strong> Conversation cleared. How can I help you?</div>';
    }
}

// Show status message
function showStatus(message, type = 'success') {
    const statusDiv = document.getElementById('status');
    statusDiv.className = 'status ' + type;
    statusDiv.textContent = message;
    statusDiv.style.display = 'block';
    
    setTimeout(() => {
        statusDiv.style.display = 'none';
    }, 3000);
}

// Add message to chat
function addMessage(text, type = 'agent') {
    const messagesDiv = document.getElementById('messages');
    const messageDiv = document.createElement('div');
    messageDiv.className = 'message ' + type;
    
    const prefix = type === 'user' ? 'You' : type === 'error' ? 'Error' : 'Agent';
    messageDiv.innerHTML = `<strong>${prefix}:</strong> ${text}`;
    
    messagesDiv.appendChild(messageDiv);
    messagesDiv.scrollTop = messagesDiv.scrollHeight;
    
    saveHistory();
}

// Handle Enter key press
function handleKeyPress(event) {
    if (event.key === 'Enter') {
        sendQuestion();
    }
}

// API endpoint - Update this with your Lambda/API Gateway URL after deployment
let API_ENDPOINT = localStorage.getItem('apiEndpoint') || 'https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat';

// Set API endpoint
function setApiEndpoint() {
    const endpoint = prompt('Enter your API Gateway endpoint URL:', API_ENDPOINT);
    if (endpoint) {
        API_ENDPOINT = endpoint.trim();
        localStorage.setItem('apiEndpoint', API_ENDPOINT);
        showStatus('API endpoint saved!', 'success');
    }
}

// Send question to Bedrock Agent via Lambda proxy
async function sendQuestion() {
    const input = document.getElementById('questionInput');
    const question = input.value.trim();
    const sendButton = document.getElementById('sendButton');
    
    if (!question) {
        return;
    }
    
    // Ensure API endpoint is set (use hardcoded default if not)
    if (!API_ENDPOINT) {
        API_ENDPOINT = 'https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat';
    }
    
    // Validate config (optional, can use Lambda defaults)
    if (!config.agentId || !config.agentAliasId) {
        showStatus('Using default Agent ID and Alias ID from Lambda configuration', 'success');
    }
    
    // Disable input
    input.disabled = true;
    sendButton.disabled = true;
    sendButton.innerHTML = 'Sending<span class="loading"></span>';
    
    // Add user message
    addMessage(question, 'user');
    input.value = '';
    
    try {
        // Call Lambda proxy via API Gateway
        const response = await fetch(API_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                agentId: config.agentId,
                agentAliasId: config.agentAliasId,
                sessionId: config.sessionId,
                question: question
            })
        });
        
        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ error: response.statusText }));
            throw new Error(errorData.error || `HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        
        if (data.error) {
            throw new Error(data.error);
        }
        
        const agentResponse = data.response || 'No response received';
        addMessage(agentResponse, 'agent');
        
    } catch (error) {
        console.error('Error:', error);
        let errorMessage = error.message || 'Unknown error occurred';
        
        if (errorMessage.includes('Failed to fetch') || errorMessage.includes('NetworkError')) {
            errorMessage = 'Cannot reach API endpoint. Check the URL and ensure CORS is enabled.';
        } else if (errorMessage.includes('403') || errorMessage.includes('Forbidden')) {
            errorMessage = 'Access denied. Check IAM permissions for Bedrock Agent.';
        } else if (errorMessage.includes('404')) {
            errorMessage = 'Agent not found. Check Agent ID and Alias ID.';
        }
        
        addMessage(errorMessage, 'error');
        showStatus('Error: ' + errorMessage, 'error');
    } finally {
        // Re-enable input
        input.disabled = false;
        sendButton.disabled = false;
        sendButton.textContent = 'Send';
    }
}


// Initialize on page load
window.addEventListener('DOMContentLoaded', () => {
    loadConfig();
    loadHistory();
    
    // Load API endpoint (fallback to hardcoded)
    API_ENDPOINT = localStorage.getItem('apiEndpoint') || 'https://f7tvfb3c2c.execute-api.eu-central-1.amazonaws.com/prod/chat';
    if (API_ENDPOINT) {
        showStatus('Ready to chat! Ask about your data.', 'success');
    }
});

