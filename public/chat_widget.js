document.addEventListener('DOMContentLoaded', function () {
  const config = window.chatWidgetConfig || {};
  
  // Set defaults on our side instead of in the config
  const settings = {
    primary_color: config.primary_color || '#000000',
    font_family: config.font_family || "'Open Sans', sans-serif", // Default font if not provided
    widget_heading: config.widget_heading || 'AI Assistant', 
    adminAccountEmail: config.adminAccountEmail
  };

  const selected_colour = settings.primary_color;
  const font_family = settings.font_family;
  const widget_heading = settings.widget_heading;
  const adminAccountEmail = settings.adminAccountEmail || 'jamie.w.ahale@gmail.com'; // TODO: Make this my account for backups
  
  // Dynamically inject a CSS rule to apply the desired font-family for the widget.
  const widgetStyle = document.createElement('style');
  widgetStyle.innerHTML = `
    #chat-icon, #chat-container, #chat-container * {
      font-family: ${font_family} !important;
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
    <div class="card-header text-white d-flex justify-content-between align-items-center" style="background-color: ${selected_colour};">
      <span><strong>${widget_heading}</strong></span>
      <button type="button" id="close-chat" class="btn-close btn-close-white"></button>
    </div>
    <div id="chat-window" class="card-body overflow-auto" style="height: 400px;"></div>
    <div id="potential-queries" class="p-2 d-flex justify-content-end flex-wrap"></div>
    <form id="chat-form" class="card-footer d-flex align-items-center p-2" style="width: 100%;">
      <textarea id="user-input" class="form-control me-2 focus-ring focus-ring-secondary" placeholder="Type your message..." rows="1" style="resize: none; overflow-y: auto; max-height: 100px;"></textarea>
      <button type="submit" id="send-button" class="btn btn-primary" style="background-color: ${selected_colour};"><i class="fas fa-paper-plane"></i></button>
    </form>
  `;
  document.body.appendChild(chatContainer);

  const sendButton = document.getElementById('send-button');
  sendButton.style.border = 'none';
  sendButton.style.outline = 'none';
  sendButton.style.padding = '12px 12px';
  sendButton.style.fontSize = '1.2em';
  console.log('selected_colour: ', selected_colour);

  const textInput = document.getElementById('user-input');
  // textInput.classList.add('focus-ring');
  // textInput.style.setProperty('--bs-focus-ring-color', `${selected_colour}40`);

  // Initial styles for chat components
  chatContainer.style.width = '350px';
  chatContainer.style.bottom = '90px';
  chatContainer.style.right = '20px';
  chatContainer.style.display = 'none';
  chatContainer.style.height = 'auto'; // Ensure it opens to full size

  chatIcon.style.position = 'fixed';
  chatIcon.style.bottom = '20px';
  chatIcon.style.right = '20px';
  chatIcon.style.width = '60px';
  chatIcon.style.height = '60px';
  chatIcon.style.backgroundColor = '#007bff';
  chatIcon.style.color = 'white';
  chatIcon.style.borderRadius = '50%';
  chatIcon.style.display = 'flex';
  chatIcon.style.justifyContent = 'center';
  chatIcon.style.alignItems = 'center';
  chatIcon.style.cursor = 'pointer';
  chatIcon.style.boxShadow = '0 4px 8px rgba(0, 0, 0, 0.2)';
  chatIcon.style.fontSize = '1.7em';
  chatIcon.style.backgroundColor = selected_colour;

  // Retrieve or generate a unique identifier
  let uniqueIdentifier = JSON.parse(localStorage.getItem('uniqueIdentifierData'));
  const now = new Date().getTime();

  // Toggle chat visibility
  chatIcon.addEventListener('click', () => {
    chatContainer.style.display = 'block';
    console.log('hasLoadedMessages:', hasLoadedMessages);

    if (!hasLoadedMessages) {
      console.log('Loading messages...');
      if (localStorage.getItem('initialMessageShown') === 'true' && uniqueIdentifier) {
        // Fetch the last 10 messages for the conversation
        fetch(`http://localhost:3000/api/v1/chat/${uniqueIdentifier.id}/last_messages`)
          .then(response => response.json())
          .then(data => {
            console.log('Fetched data:', data);
            if (data.messages && data.messages.length > 0) {
              data.messages.forEach(message => {
                // Process formatting for each message
                const formattedUserQuery = message.user_query
                  .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
                  .replace(/\n/g, '<br>');
                const formattedAssistantResponse = message.assistant_response
                  .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
                  .replace(/\n/g, '<br>');

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
  });

  function displayInitialMessage() {
    const initialMessage = document.createElement('div');
    initialMessage.innerHTML = `
      <div class="text-start mb-2">
        <div class="text-white p-2 rounded d-inline-block" style="max-width: 80%; background-color: ${selected_colour};">
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
  closeChat.addEventListener('click', () => {
    chatContainer.style.display = 'none';
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
  form.style.alignItems = 'flex-end';
  form.style.bottom = '0';
  form.style.width = '100%';
  form.style.backgroundColor = '#f8f9fa';

  // Adjust the user input to expand upwards
  userInput.style.flex = '1';
  userInput.style.border = 'none';
  userInput.style.borderRadius = '5px';
  userInput.style.padding = '10px';
  userInput.style.resize = 'none';
  userInput.style.overflowY = 'auto';
  userInput.style.maxHeight = '100px'; // Set a maximum height


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

    // Display user's message
    const userMessage = document.createElement('div');
    userMessage.innerHTML = `
      <div class="text-end mb-2">
        <div class="text-light p-2 rounded d-inline-block" style="max-width: 80%; background-color: ${selected_colour}; opacity: 0.7;">
          <strong>You:</strong> ${userInput.value}
        </div>
      </div>
    `;
    chatWindow.appendChild(userMessage);

    // Display loading message
    const loadingMessage = document.createElement('div');
    loadingMessage.innerHTML = `
      <div class="text-start mb-2">
        <div class="text-white p-2 rounded d-inline-block" style="width: auto; max-width: 80%; background-color: ${selected_colour};">
          <i class="fas fa-circle fa-bounce" style="font-size: 0.5em; animation-delay: 0s;"></i>
          <i class="fas fa-circle fa-bounce" style="font-size: 0.5em; animation-delay: 0.2s;"></i>
          <i class="fas fa-circle fa-bounce" style="font-size: 0.5em; animation-delay: 0.4s;"></i>
        </div>
      </div>
    `;
    chatWindow.appendChild(loadingMessage);
    chatWindow.scrollTop = chatWindow.scrollHeight;

    // Send message to API
    fetch('http://localhost:3000/api/v1/chat', {
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
      }),
    })
      .then((response) => response.json())
      .then((data) => {
        chatWindow.removeChild(loadingMessage);

        const assistantMessage = document.createElement('div');
        assistantMessage.innerHTML = `
          <div class="text-start mb-2">
            <div class="text-white p-2 rounded d-inline-block" style="width: auto; max-width: 80%; background-color: ${selected_colour};">
              <strong>Assistant:</strong> ${
                data.cleaned_response
                  .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
                  .replace(/\n/g, '<br>') || 'No valid response received.'
              }
            </div>
          </div>
        `;
        chatWindow.appendChild(assistantMessage);
        chatWindow.scrollTop = chatWindow.scrollHeight;

        // Display potential queries as buttons
        if (data.potential_queries) {
          data.potential_queries.forEach(query => {
            const queryButton = document.createElement('button');
            queryButton.textContent = query;
            
            // Apply the styles directly when creating the button
            queryButton.style.border = `1px solid ${selected_colour}`;
            queryButton.style.backgroundColor = 'transparent';
            queryButton.style.color = selected_colour;
            queryButton.style.padding = '5px 10px';
            queryButton.style.borderRadius = '15px';
            queryButton.style.cursor = 'pointer';
            queryButton.style.transition = 'all 0.3s';
            queryButton.style.margin = '2px';
            
            // Add hover event listeners
            queryButton.addEventListener('mouseover', () => {
              queryButton.style.backgroundColor = selected_colour;
              queryButton.style.color = 'white';
            });
            
            queryButton.addEventListener('mouseout', () => {
              queryButton.style.backgroundColor = 'transparent';
              queryButton.style.color = selected_colour;
            });

            queryButton.addEventListener('click', () => {
              userInput.value = query;
              form.dispatchEvent(new Event('submit'));
            });
            
            potentialQueriesContainer.appendChild(queryButton);
          });
          chatWindow.scrollTop = chatWindow.scrollHeight;
        }
      })
      .catch((error) => {
        chatWindow.removeChild(loadingMessage);
        const errorMessage = document.createElement('div');
        errorMessage.innerHTML = `
          <div class="text-start mb-2">
            <div class="bg-danger text-white p-2 rounded d-inline-block" style="width: auto; max-width: 80%;">
              <strong>Error:</strong> Unable to get a response from the assistant.
            </div>
          </div>
        `;
        chatWindow.appendChild(errorMessage);
        chatWindow.scrollTop = chatWindow.scrollHeight;
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
