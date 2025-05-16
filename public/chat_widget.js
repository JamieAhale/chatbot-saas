document.addEventListener('DOMContentLoaded', function () {
  const config = window.chatWidgetConfig || {};
  
  // Set defaults on our side instead of in the config
  const settings = {
    primary_color: validateColor(config.primary_color) || '#000000',
    font_family: validateFontFamily(config.font_family) || "'Open Sans', sans-serif", // Default font if not provided
    widget_heading: sanitizeHTML(config.widget_heading) || 'AI Assistant', 
    adminAccountEmail: sanitizeEmail(config.adminAccountEmail)
  };

  // Determine if we're in production or development based on the current URL
  const isProduction = window.location.hostname !== 'localhost' && 
                      !window.location.hostname.includes('127.0.0.1') && 
                      window.location.protocol !== 'file:';
  const apiBaseUrl = isProduction 
    ? 'https://chatbot-saas-e0691e8fb948.herokuapp.com' 
    : 'http://localhost:3000';
  
  console.log('Environment:', isProduction ? 'Production' : 'Development');
  console.log('API Base URL:', apiBaseUrl);

  // Initialize FingerprintJS
  let visitorId = null;
  // Initialize the FingerprintJS agent
  const fpPromise = import('https://openfpcdn.io/fingerprintjs/v4')
    .then(FingerprintJS => FingerprintJS.load())
    .catch(error => {
      console.error('Error loading FingerprintJS:', error);
      return null;
    });

  // Get visitor identifier when available
  fpPromise
    .then(fp => fp ? fp.get() : null)
    .then(result => {
      if (result) {
        visitorId = result.visitorId;
        console.log('FingerprintJS Visitor ID:', visitorId);
      }
    })
    .catch(error => {
      console.error('Error getting visitor ID:', error);
    });

  // Improved sanitization function to prevent XSS attacks
  function sanitizeHTML(text) {
    if (!text) return '';
    const element = document.createElement('div');
    element.textContent = text;
    return element.innerHTML;
  }

  // Function to validate color to ensure it's a valid hex color code
  function validateColor(color) {
    return /^#[0-9A-F]{6}$/i.test(color) ? color : '#000000';
  }

  // Function to validate font family against allowed list
  function validateFontFamily(fontFamily) {
    const allowedFonts = [
      "'Roboto', sans-serif", "'Open Sans', sans-serif", "'Lato', sans-serif", 
      "'Poppins', sans-serif", "'Montserrat', sans-serif", "'Source Sans Pro', sans-serif",
      "'Nunito', sans-serif", "'Inter', sans-serif", "'Ubuntu', sans-serif",
      "'Playfair Display', serif", "'Quicksand', sans-serif", "'Raleway', sans-serif",
      "Arial, sans-serif", "'Helvetica Neue', Helvetica, sans-serif", 
      "'Segoe UI', Tahoma, Geneva, sans-serif", "'Times New Roman', serif"
    ];
    
    return allowedFonts.includes(fontFamily) ? fontFamily : "'Open Sans', sans-serif";
  }

  // Function to sanitize email
  function sanitizeEmail(email) {
    if (!email) return '';
    // Basic email validation
    if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return email;
    }
    return '';
  }

  // Function to safely format messages with markdown-like formatting
  function formatMessage(message) {
    if (!message) return '';
    return sanitizeHTML(message)
      .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
      .replace(/\n/g, '<br>');
  }
  
  const selected_colour = settings.primary_color;
  const font_family = settings.font_family;
  const widget_heading = settings.widget_heading;
  const adminAccountEmail = settings.adminAccountEmail || '';
  
  // Dynamically inject a CSS rule to apply the desired font-family for the widget.
  const widgetStyle = document.createElement('style');
  widgetStyle.innerHTML = `
    #chat-icon, #chat-container, #chat-container * {
      font-family: ${font_family} !important;
    }
    
    #chat-container .card-footer {
      padding: 0 !important;
      margin: 0 !important;
      border-top: none !important;
      background-color: white !important;
    }
    
    #chat-container form {
      margin-bottom: 0 !important;
    }
    
    #chat-container #user-input {
      border: 1px solid ${selected_colour}40 !important;
      outline: none !important;
    }
    
    #chat-container #user-input:focus {
      border-color: ${selected_colour} !important;
      box-shadow: 0 0 0 0.2rem ${selected_colour}30 !important;
    }
  `;
  document.head.appendChild(widgetStyle);

  // Override the font for Font Awesome icons specifically so they display correctly
  const iconOverrideStyle = document.createElement('style');
  iconOverrideStyle.innerHTML = `
    #chat-container i.fas {
      font-family: "Font Awesome 6 Free" !important;
      font-weight: 900; /* Adjust if necessary depending on your FA version */
    }
  `;
  document.head.appendChild(iconOverrideStyle);

  // Helper function to extract the primary font name from the font-family string.
  // E.g., given "'Roboto', sans-serif" it returns "Roboto".
  function extractFontName(fontFamilyStr) {
    const match = fontFamilyStr.match(/^['"]?([^,'"]+)['"]?/);
    return match ? match[1] : fontFamilyStr;
  }

  const fontName = extractFontName(font_family);
  console.log("Extracted font name:", fontName);

  // Known Google Fonts options based on your widget generator dropdown:
  const googleFonts = ["Roboto", "Open Sans", "Lato", "Poppins", "Montserrat", "Source Sans Pro", "Nunito", "Inter", "Ubuntu", "Playfair Display", "Quicksand", "Raleway"];

  // If the extracted font name is a Google Font, load it dynamically.
  if (googleFonts.includes(fontName)) {
    const googleFontLink = document.createElement('link');
    googleFontLink.rel = 'stylesheet';
    // Replace spaces with '+' for the URL
    const fontNameUrl = fontName.split(' ').join('+');
    // Here we load weights 400, 600, and 700; adjust as needed.
    googleFontLink.href = `https://fonts.googleapis.com/css2?family=${fontNameUrl}:wght@400;600;700&display=swap`;
    document.head.appendChild(googleFontLink);
  }

  // Load Bootstrap CSS dynamically
  const bootstrapLink = document.createElement('link');
  bootstrapLink.rel = 'stylesheet';
  bootstrapLink.href = 'https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css'; // Load Bootstrap
  document.head.appendChild(bootstrapLink);

  // Load FontAwesome for icons dynamically
  const faLink = document.createElement('link');
  faLink.rel = 'stylesheet';
  faLink.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css'; // Load FontAwesome
  document.head.appendChild(faLink);

  const fontAwesomeScript = document.createElement('script');
  fontAwesomeScript.src = 'https://kit.fontawesome.com/aee17d2e29.js'; // Load FontAwesome
  document.head.appendChild(fontAwesomeScript);

  const assistantName = 'example-assistant';
  let hasLoadedMessages = false;
  console.log('uniqueIdentifierData: ', localStorage.getItem('uniqueIdentifierData'));

  // Create the chat icon
  const chatIcon = document.createElement('div');
  chatIcon.id = 'chat-icon';
  chatIcon.innerHTML = '<i class="fas fa-comments"></i>';
  chatIcon.style.backgroundColor = selected_colour;
  document.body.appendChild(chatIcon);

  // Create the chat container with customizable heading
  const chatContainer = document.createElement('div');
  chatContainer.id = 'chat-container';
  chatContainer.classList.add('card', 'shadow', 'rounded', 'position-fixed');
  chatContainer.innerHTML = `
    <div class="card-header text-white d-flex justify-content-between align-items-center" style="background-color: ${selected_colour}; border-bottom: none; padding: 15px;">
      <span class="fs-5"><strong>${widget_heading}</strong></span>
      <button type="button" id="close-chat" class="btn-close btn-close-white" style="opacity: 0.8;"></button>
    </div>
    <div id="chat-window" class="card-body overflow-auto" style="height: 400px;"></div>
    <div id="potential-queries" class="p-2 d-flex justify-content-end flex-wrap"></div>
    <div class="card-footer p-0" style="background-color: #fff; border-top: 1px solid rgba(0,0,0,0.1); padding: 8px !important;">
      <form id="chat-form" class="d-flex align-items-end gap-2 p-1" style="width: 100%;">
        <textarea id="user-input" class="form-control" placeholder="Type your message..." rows="1" style="resize: none; overflow-y: auto; max-height: 100px; padding: 10px; border-radius: 20px; box-shadow: none;"></textarea>
        <button type="submit" id="send-button" class="btn d-flex align-items-center justify-content-center" style="width: 42px; height: 42px; padding: 0; border-radius: 50%;"><i class="fas fa-paper-plane" style="color: white;"></i></button>
      </form>
    </div>
  `;
  document.body.appendChild(chatContainer);

  const sendButton = document.getElementById('send-button');
  sendButton.style.backgroundColor = selected_colour;
  sendButton.style.border = 'none';
  sendButton.style.transition = 'all 0.2s ease';
  sendButton.style.boxShadow = '0 2px 5px rgba(0,0,0,0.1)';

  // Add hover effect to send button
  sendButton.addEventListener('mouseenter', () => {
    sendButton.style.transform = 'scale(1.05)';
    sendButton.style.boxShadow = '0 4px 8px rgba(0,0,0,0.2)';
  });

  sendButton.addEventListener('mouseleave', () => {
    sendButton.style.transform = 'scale(1)';
    sendButton.style.boxShadow = '0 2px 5px rgba(0,0,0,0.1)';
  });

  const textInput = document.getElementById('user-input');
  textInput.style.transition = 'all 0.3s ease';
  textInput.style.border = `1px solid ${selected_colour}20`;
  
  // Add focus effect to input
  textInput.addEventListener('focus', function() {
    this.style.border = `2px solid ${selected_colour}40`;
    this.style.boxShadow = `0 0 0 4px ${selected_colour}15`;
  });
  
  textInput.addEventListener('blur', function() {
    this.style.border = `1px solid ${selected_colour}20`;
    this.style.boxShadow = 'none';
  });

  // Initial styles for chat components
  chatContainer.style.width = 'min(400px, 85vw)';
  chatContainer.style.bottom = '90px';
  chatContainer.style.right = '20px';
  chatContainer.style.display = 'none';
  chatContainer.style.height = 'auto';
  chatContainer.style.overflow = 'hidden';
  chatContainer.style.transition = 'all 0.3s ease-in-out';
  chatContainer.style.zIndex = '10000';
  chatContainer.style.borderRadius = '15px';
  chatContainer.style.boxShadow = '0 5px 25px rgba(0,0,0,0.15)';
  chatContainer.style.transform = 'translateY(20px)';
  chatContainer.style.opacity = '0';

  chatIcon.style.position = 'fixed';
  chatIcon.style.bottom = '20px';
  chatIcon.style.right = '20px';
  chatIcon.style.width = '60px';
  chatIcon.style.height = '60px';
  chatIcon.style.backgroundColor = selected_colour;
  chatIcon.style.color = 'white';
  chatIcon.style.borderRadius = '50%';
  chatIcon.style.display = 'flex';
  chatIcon.style.justifyContent = 'center';
  chatIcon.style.alignItems = 'center';
  chatIcon.style.cursor = 'pointer';
  chatIcon.style.boxShadow = '0 4px 15px rgba(0, 0, 0, 0.2)';
  chatIcon.style.fontSize = '1.7em';
  chatIcon.style.transition = 'all 0.3s ease-in-out';
  chatIcon.style.zIndex = '10000';

  // Add hover effect to chat icon
  chatIcon.addEventListener('mouseenter', () => {
    chatIcon.style.transform = 'scale(1.2)';
    chatIcon.style.borderRadius = '35%';
    chatIcon.style.boxShadow = '0 8px 20px rgba(0, 0, 0, 0.3)';
  });

  chatIcon.addEventListener('mouseleave', () => {
    chatIcon.style.transform = 'scale(1)';
    chatIcon.style.borderRadius = '50%';
    chatIcon.style.boxShadow = '0 4px 15px rgba(0, 0, 0, 0.2)';
  });

  // Retrieve or generate a unique identifier
  let uniqueIdentifier = JSON.parse(localStorage.getItem('uniqueIdentifierData'));
  const now = new Date().getTime();

  // Toggle chat visibility with animation
  chatIcon.addEventListener('click', () => {
    if (chatContainer.style.display === 'none') {
      chatContainer.style.display = 'block';
      // Trigger reflow
      chatContainer.offsetHeight;
      chatContainer.style.transform = 'translateY(0)';
      chatContainer.style.opacity = '1';
      
      if (!hasLoadedMessages) {
        console.log('Loading messages...');
        if (localStorage.getItem('initialMessageShown') === 'true' && uniqueIdentifier) {
          // Fetch the last 10 messages for the conversation
          fetch(`${apiBaseUrl}/api/v1/chat/${uniqueIdentifier.id}/last_messages`)
            .then(response => response.json())
            .then(data => {
              console.log('Fetched data:', data);
              if (data.messages && data.messages.length > 0) {
                data.messages.forEach(message => {
                  // Process formatting for each message using our safe formatter
                  const formattedUserQuery = formatMessage(message.user_query);
                  const formattedAssistantResponse = formatMessage(message.assistant_response);

                  const userMessage = document.createElement('div');
                  userMessage.innerHTML = `
                    <div class="text-end mb-2">
                      <div class="text-light p-2 rounded d-inline-block" style="max-width: 80%; background-color: ${selected_colour}; opacity: 0.7;">
                        <strong>You:</strong> ${formattedUserQuery}
                      </div>
                    </div>
                  `;
                  chatWindow.appendChild(userMessage);

                  const assistantMessage = document.createElement('div');
                  assistantMessage.innerHTML = `
                    <div class="text-start mb-2">
                      <div class="text-white p-2 rounded d-inline-block" style="max-width: 90%; background-color: ${selected_colour};">
                        <strong>Assistant:</strong> ${formattedAssistantResponse}
                      </div>
                    </div>
                  `;
                  chatWindow.appendChild(assistantMessage);
                });
                chatWindow.scrollTop = chatWindow.scrollHeight;
              } else {
                displayInitialMessage();
              }
              hasLoadedMessages = true;
              console.log('Messages loaded, flag set to true');
            })
            .catch(error => {
              console.error('Error fetching messages:', error);
              displayInitialMessage();
              hasLoadedMessages = true;
            });
        } else {
          displayInitialMessage();
          hasLoadedMessages = true;
        }
      }
    }
  });

  // Add a function to get standardized message bubble styling
  function getMessageStyle(isUser = false) {
    const baseStyle = `
      min-height: 18px;
      display: flex;
      align-items: center;
      border-radius: 20px;
      padding: 8px 16px;
      box-shadow: 0 2px 5px rgba(0,0,0,0.1);
      max-width: 85%;
    `;
    return isUser ? 
      `${baseStyle} background-color: ${selected_colour}; opacity: 0.85;` :
      `${baseStyle} background-color: ${selected_colour};`;
  }

  // Update error message display
  function displayErrorMessage(message) {
    const errorMessage = document.createElement('div');
    errorMessage.innerHTML = `
      <div class="text-start mb-3" style="animation: slideFromLeft 0.3s ease-out;">
        <div class="text-white d-inline-block" style="${getMessageStyle()}">
          <strong>Error:</strong> ${message}
        </div>
      </div>
    `;
    chatWindow.appendChild(errorMessage);
    chatWindow.scrollTop = chatWindow.scrollHeight;
  }

  function displayInitialMessage() {
    const initialMessage = document.createElement('div');
    initialMessage.innerHTML = `
      <div class="text-start mb-3" style="animation: slideFromLeft 0.3s ease-out;">
        <div class="text-white d-inline-block" style="${getMessageStyle()}">
          <strong>Assistant:</strong> How can I help you today?
        </div>
      </div>
    `;
    chatWindow.appendChild(initialMessage);
    chatWindow.scrollTop = chatWindow.scrollHeight;
    localStorage.setItem('initialMessageShown', 'true');
  }

  // Check if the identifier exists and hasn't expired (7 days in milliseconds)
  if (!uniqueIdentifier || now - uniqueIdentifier.timestamp > 7 * 24 * 60 * 60 * 1000) {
   uniqueIdentifier = {
     id: 'user-' + Math.random().toString(36).substr(2, 9),
     timestamp: now,
   };
   localStorage.setItem('uniqueIdentifierData', JSON.stringify(uniqueIdentifier));
  }

  console.log('uniqueIdentifier: ', uniqueIdentifier);

  const closeChat = document.getElementById('close-chat');
  closeChat.style.transition = 'all 0.3s ease';
  closeChat.style.opacity = '0.7';
  closeChat.style.transform = 'scale(1)';
  
  closeChat.addEventListener('mouseenter', () => {
    closeChat.style.opacity = '1';
    closeChat.style.transform = 'scale(1.2) rotate(90deg)';
  });
  
  closeChat.addEventListener('mouseleave', () => {
    closeChat.style.opacity = '0.7';
    closeChat.style.transform = 'scale(1) rotate(0deg)';
  });

  closeChat.addEventListener('click', () => {
    chatContainer.style.transform = 'translateY(20px)';
    chatContainer.style.opacity = '0';
    
    // Wait for animation to complete before hiding
    setTimeout(() => {
      chatContainer.style.display = 'none';
    }, 300);
  });

  // Handle sending messages
  const form = document.getElementById('chat-form');
  const chatWindow = document.getElementById('chat-window');
  const userInput = document.getElementById('user-input');
  const potentialQueriesContainer = document.getElementById('potential-queries');

  // Ensure the chat container is positioned relative to allow absolute positioning of the form
  chatContainer.style.position = 'relative';

  // Adjust the chat form to be anchored at the bottom
  form.style.display = 'flex';
  form.style.alignItems = 'center';
  form.style.width = '100%';
  form.style.margin = '0';
  form.style.padding = '8px';

  // Adjust the user input to expand upwards
  userInput.style.flex = '1';
  userInput.style.border = `1px solid ${selected_colour}40`; // Faint outline using the selected color with 25% opacity
  userInput.style.borderRadius = '5px';
  userInput.style.padding = '10px';
  userInput.style.resize = 'none';
  userInput.style.overflowY = 'auto';
  userInput.style.maxHeight = '100px'; // Set a maximum height
  userInput.style.marginBottom = '0'; // Ensure no bottom margin
  
  // Add custom focus style
  userInput.addEventListener('focus', function() {
    this.style.boxShadow = `0 0 0 0.2rem ${selected_colour}30`;
    this.style.borderColor = selected_colour;
  });
  
  userInput.addEventListener('blur', function() {
    this.style.boxShadow = 'none';
    this.style.borderColor = `${selected_colour}40`; // Return to faint outline
  });

  // Dynamically adjust the height of the textarea and the chat form
  userInput.addEventListener('input', function () {
    this.style.height = 'auto';
    this.style.height = `${Math.min(this.scrollHeight, 100)}px`;
  });

  // Ensure the chat window is scrollable
  chatWindow.style.overflowY = 'auto';

  // Submit on Enter key press
  userInput.addEventListener('keydown', function (event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      form.dispatchEvent(new Event('submit'));
    }
  });

  form.addEventListener('submit', function (event) {
    event.preventDefault();

    if (userInput.value.trim() === '') {
      return;
    }

    // Clear potential queries when a message is sent
    potentialQueriesContainer.innerHTML = '';

    // Display user's message with sanitization
    const userMessage = document.createElement('div');
    userMessage.innerHTML = `
      <div class="text-end mb-3" style="animation: slideFromRight 0.3s ease-out;">
        <div class="text-light d-inline-block" style="${getMessageStyle(true)}">
          <strong>You:</strong> ${sanitizeHTML(userInput.value)}
        </div>
      </div>
    `;
    chatWindow.appendChild(userMessage);

    // Display loading message
    const loadingMessage = document.createElement('div');
    loadingMessage.innerHTML = `
      <div class="text-start mb-3" style="animation: fadeIn 0.3s ease-out;">
        <div class="text-white d-inline-block" style="${getMessageStyle()}">
          <div style="display: flex; gap: 4px; align-items: center;">
            <i class="fas fa-circle fa-bounce" style="font-size: 0.5em; animation-delay: 0s;"></i>
            <i class="fas fa-circle fa-bounce" style="font-size: 0.5em; animation-delay: 0.2s;"></i>
            <i class="fas fa-circle fa-bounce" style="font-size: 0.5em; animation-delay: 0.4s;"></i>
          </div>
        </div>
      </div>
    `;

    // Add animation styles to the document
    if (!document.getElementById('message-animations')) {
      const styleSheet = document.createElement('style');
      styleSheet.id = 'message-animations';
      styleSheet.textContent = `
        @keyframes slideFromRight {
          from {
            opacity: 0;
            transform: translateX(20px);
          }
          to {
            opacity: 1;
            transform: translateX(0);
          }
        }
        @keyframes slideFromLeft {
          from {
            opacity: 0;
            transform: translateX(-20px);
          }
          to {
            opacity: 1;
            transform: translateX(0);
          }
        }
        @keyframes fadeIn {
          from {
            opacity: 0;
          }
          to {
            opacity: 1;
          }
        }
      `;
      document.head.appendChild(styleSheet);
    }

    chatWindow.appendChild(loadingMessage);
    chatWindow.scrollTop = chatWindow.scrollHeight;

    // Update the chat window styling
    const chatWindowElement = document.getElementById('chat-window');
    chatWindowElement.style.padding = '20px';
    chatWindowElement.style.backgroundColor = '#f8f9fa';
    chatWindowElement.style.height = '400px';
    chatWindowElement.style.overflowY = 'auto';
    chatWindowElement.style.scrollBehavior = 'smooth';

    // Send message to API
    fetch(`${apiBaseUrl}/api/v1/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: JSON.stringify({
        user_input: userInput.value,
        unique_identifier: uniqueIdentifier.id,
        assistant_name: assistantName,
        admin_account_email: adminAccountEmail,
        visitor_id: visitorId // Include the FingerprintJS visitor ID
      }),
    })
      .then((response) => response.json())
      .then((data) => {
        chatWindow.removeChild(loadingMessage);

        const assistantMessage = document.createElement('div');
        assistantMessage.innerHTML = `
          <div class="text-start mb-3" style="animation: slideFromLeft 0.3s ease-out;">
            <div class="text-white d-inline-block" style="${getMessageStyle()}">
              <strong>Assistant:</strong> ${
                formatMessage(data.cleaned_response) || 'No valid response received.'
              }
            </div>
          </div>
        `;
        chatWindow.appendChild(assistantMessage);
        chatWindow.scrollTop = chatWindow.scrollHeight;

        // Display potential queries as buttons
        if (data.potential_queries && data.potential_queries.length > 0) {
          potentialQueriesContainer.innerHTML = ''; // Clear existing queries
          data.potential_queries.forEach(query => {
            const queryButton = document.createElement('button');
            queryButton.textContent = query;
            
            // Apply modern styling to query buttons
            queryButton.style.border = `1px solid ${selected_colour}40`;
            queryButton.style.backgroundColor = '#fff';
            queryButton.style.color = selected_colour;
            queryButton.style.padding = '8px 16px';
            queryButton.style.borderRadius = '20px';
            queryButton.style.cursor = 'pointer';
            queryButton.style.transition = 'all 0.2s ease';
            queryButton.style.margin = '4px';
            queryButton.style.fontSize = '0.9em';
            queryButton.style.fontWeight = '500';
            queryButton.style.boxShadow = '0 2px 4px rgba(0,0,0,0.05)';
            queryButton.style.maxWidth = '100%';
            queryButton.style.overflow = 'hidden';
            queryButton.style.textOverflow = 'ellipsis';
            queryButton.style.whiteSpace = 'nowrap';
            queryButton.style.border = 'none';
            
            // Add hover effects
            queryButton.addEventListener('mouseover', () => {
              queryButton.style.backgroundColor = selected_colour;
              queryButton.style.color = 'white';
              queryButton.style.transform = 'translateY(-1px)';
              queryButton.style.boxShadow = '0 4px 8px rgba(0,0,0,0.1)';
            });
            
            queryButton.addEventListener('mouseout', () => {
              queryButton.style.backgroundColor = '#fff';
              queryButton.style.color = selected_colour;
              queryButton.style.transform = 'translateY(0)';
              queryButton.style.boxShadow = '0 2px 4px rgba(0,0,0,0.05)';
            });

            queryButton.addEventListener('click', () => {
              userInput.value = query;
              form.dispatchEvent(new Event('submit'));
            });
            
            potentialQueriesContainer.appendChild(queryButton);
          });

          // Style the container for potential queries
          potentialQueriesContainer.style.padding = '10px 15px';
          potentialQueriesContainer.style.borderTop = '1px solid rgba(0,0,0,0.1)';
          potentialQueriesContainer.style.backgroundColor = '#f8f9fa';
          potentialQueriesContainer.style.display = 'flex';
          potentialQueriesContainer.style.flexWrap = 'wrap';
          potentialQueriesContainer.style.gap = '4px';
          potentialQueriesContainer.style.justifyContent = 'flex-end';
          potentialQueriesContainer.style.alignItems = 'center';
          potentialQueriesContainer.style.maxHeight = 'none';
          potentialQueriesContainer.style.overflowY = 'visible';
        }
      })
      .catch((error) => {
        chatWindow.removeChild(loadingMessage);
        displayErrorMessage('Unable to get a response from the assistant.');
      });

    // Clear the input after sending
    userInput.value = '';
    userInput.style.height = 'auto'; // Reset height after sending
  });

  // Adjust chat window height based on potential queries
  //function adjustChatWindowHeight() {
    //const hasQueries = potentialQueriesContainer.children.length > 0;
    //chatWindow.style.height = hasQueries ? '400px' : '480px';
  //}

  // Clear the initial message flag on page reload
  window.addEventListener('beforeunload', function () {
    //localStorage.removeItem('initialMessageShown');
    //localStorage.removeItem('uniqueIdentifierData');
    chatContainer.style.display = 'none';
    hasLoadedMessages = false;
    console.log('Reset hasLoadedMessages on unload');
  });

  // Add this CSS to the potential queries buttons
  if (potentialQueriesContainer) {
    const buttons = potentialQueriesContainer.getElementsByTagName('button');
    Array.from(buttons).forEach(button => {
      button.style.border = `1px solid ${selected_colour}`;
      button.style.backgroundColor = 'transparent';
      button.style.color = selected_colour;
      button.style.padding = '5px 10px';
      button.style.borderRadius = '15px';
      button.style.cursor = 'pointer';
      button.style.transition = 'all 0.3s';
      button.style.margin = '2px';
      
      button.addEventListener('mouseover', () => {
        button.style.backgroundColor = selected_colour;
        button.style.color = 'white';
      });
      
      button.addEventListener('mouseout', () => {
        button.style.backgroundColor = 'transparent';
        button.style.color = selected_colour;
      });
    });
  }
});
