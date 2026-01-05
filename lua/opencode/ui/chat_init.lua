---Main entry point for custom chat frontend
local M = {}

---Start a new chat session with custom UI
---@param opts? { width?: number, height?: number }
function M.start_chat(opts)
  -- Get or start opencode server
  require("opencode.cli.server")
    .get_port(true)
    :next(function(port)
      -- Open chat window
      local chat = require("opencode.ui.chat")
      local state = chat.open(opts)

      -- Store port
      state.port = port

      -- Subscribe to events first
      require("opencode.ui.chat_events").subscribe(port)

      -- Show welcome message with instructions
      vim.schedule(function()
        if chat.get_state() then
          local config = require("opencode.config").opts.chat or {}
          local keymaps = config.keymaps or {}

          -- Format keymaps for display
          local function format_keys(keys)
            if type(keys) == "string" then
              return keys
            elseif type(keys) == "table" then
              return table.concat(keys, "/")
            end
            return "?"
          end

          local send_keys = format_keys(keymaps.send or { "i", "a" })
          local new_session_key = format_keys(keymaps.new_session or "n")
          local close_keys = format_keys(keymaps.close or { "q", "<Esc>" })
          local yank_key = format_keys(keymaps.yank or "yy")
          local interrupt_key = format_keys(keymaps.interrupt or "<C-c>")

          chat.add_message({
            role = "assistant",
            text = string.format(
              "Welcome to OpenCode Chat!\nConnected to opencode server on port %d\n\nType '%s' to send a message. A session will be created if needed.\n\nKeybindings:\n  %s - Send message\n  %s - New session\n  %s - Close\n  %s - Yank message\n  %s - Interrupt",
              port,
              send_keys,
              send_keys,
              new_session_key,
              close_keys,
              yank_key,
              interrupt_key
            ),
            streaming = false,
            complete = true,
          })
        end
      end)

      -- Try to create initial session, but don't block if it fails
      local client = require("opencode.cli.client")
      client.tui_execute_command("session.new", port, function()
        -- Session will be set via SSE event
        -- If this fails, session will be created on-demand when user sends first message
      end)
    end)
    :catch(function(err)
      vim.notify("Failed to start opencode: " .. err, vim.log.levels.ERROR, { title = "opencode" })
    end)
end

return M
