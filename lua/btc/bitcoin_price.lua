local M = {}

-- Define default highlight groups (won't override if already set)
vim.cmd("highlight default StatusLineBitcoin guifg=#FFFF00 guibg=NONE")
vim.cmd("highlight default StatusLineBitcoinGreen guifg=#00FF00 guibg=NONE")
vim.cmd("highlight default StatusLineBitcoinRed guifg=#FF0000 guibg=NONE")

-- Store the current price and history for trend analysis
M.price = nil
M.history = {}
M.max_history = 60  -- store up to 60 samples (e.g. 60 minutes for a 1-hour trend)

-- Set your Bitcoin icon or symbol here
M.icon = "₿"

-- Function to fetch Bitcoin price from CoinGecko
function M.fetch_price()
  -- API endpoint (you can change this to another service if desired)
  local url = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd"
  local cmd = string.format("curl -s '%s'", url)

  -- Start an asynchronous job to fetch the price
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        -- Concatenate the returned JSON data
        local json = table.concat(data, "")
        -- Try to decode the JSON result
        local ok, decoded = pcall(vim.fn.json_decode, json)
        if ok and decoded and decoded.bitcoin and decoded.bitcoin.usd then
          local new_price = decoded.bitcoin.usd
          M.price = new_price
          -- Update history table
          table.insert(M.history, new_price)
          if #M.history > M.max_history then
            table.remove(M.history, 1)
          end
        else
          M.price = "N/A"
        end
      end
    end,
    on_exit = function()
      -- Redraw the statusline when the job is done
      vim.cmd("redrawstatus")
    end,
  })
end

-- Immediately fetch the price when the module loads
M.fetch_price()

-- Create a timer to update the price every 60 seconds (60000 ms)
local timer = vim.loop.new_timer()
timer:start(0, 60000, vim.schedule_wrap(function()
  M.fetch_price()
end))

local braille_map = {
  ["1,1"] = "⣀",
  ["1,2"] = "⣠",
  ["2,2"] = "⣤",
  ["2,1"] = "⣄",
  ["2,3"] = "⣴",
  ["2,4"] = "⣼",
  ["3,3"] = "⣶",
  ["3,2"] = "⣦",
  ["1,3"] = "⣰",
  ["4,4"] = "⣿",
  ["1,4"] = "⣸",
  ["4,2"] = "⣧",
  ["4,3"] = "⣷",
}

-- Build a simple sparkline from the history data.
-- It takes three points: the first, the middle, and the latest value.
-- Then it normalizes these values and maps them to block characters.
function M.sparkline()
  local n = #M.history
  if n < 8 then
    return ""  -- Not enough data yet to show a trend
  end

  -- Select 8 evenly spaced samples from the history
  local step = math.floor(n / 8)
  local values = {}
  for i = 1, 8 do
    table.insert(values, M.history[(i - 1) * step + 1])
  end

  -- Find min and max for normalization
  local min, max = values[1], values[1]
  for _, v in ipairs(values) do
    if v < min then min = v end
    if v > max then max = v end
  end

  -- Build the sparkline using the Braille map
  local spark = ""
  if min == max then
    -- All values are equal – use a middle block for each sample
    spark = string.rep(braille_map["2,2"], #values)  -- Example, replace with actual middle character
  else
    -- Create tuples from pairs of values
    for i = 1, #values, 2 do
      -- Normalize the first value to a range of 1 to 4
      local level1 = math.floor((values[i] - min) / (max - min) * 3 + 1)
      -- Normalize the second value to a range of 1 to 4
      local level2 = math.floor((values[i + 1] - min) / (max - min) * 3 + 1)
      -- Form a tuple from the two levels
      local tuple = string.format("%d,%d", level1, level2)
      -- Map the tuple to a Braille character
      spark = spark .. (braille_map[tuple] or "⠶")  -- Default to a character if not found
    end
  end

  return spark
end

-- Build the statusline component with colors.
-- The Bitcoin icon and price are in yellow.
-- The sparkline is green if the trend is positive (latest > oldest) and red otherwise.
function M.statusline_component()
  local price_str = M.price and string.format("$%s", M.price) or "fetching..."
  local bitcoin_str = string.format("%s %s", M.icon, price_str)
  -- Color the icon and price yellow
  local bitcoin_colored = "%#StatusLineBitcoin#" .. bitcoin_str .. "%*"

  local spark = M.sparkline()
  if spark ~= "" then
    local trend_positive = false
    if #M.history >= 2 then
      if M.history[#M.history] > M.history[1] then
        trend_positive = true
      end
    end

    local spark_colored = ""
    if trend_positive then
      spark_colored = "%#StatusLineBitcoinGreen#" .. spark .. "%*"
    else
      spark_colored = "%#StatusLineBitcoinRed#" .. spark .. "%*"
    end
    return bitcoin_colored .. " " .. spark_colored
  else
    return bitcoin_colored
  end
end

return M
