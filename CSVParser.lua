-- TMBExport CSV Parser
-- Parses ThatsMyBis.com CSV export format

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Parse a single CSV line, handling quoted fields with commas
local function ParseCSVLine(line)
    local fields = {}
    local pos = 1
    local len = #line

    while pos <= len do
        if line:sub(pos, pos) == '"' then
            -- Quoted field
            local value = ""
            pos = pos + 1 -- skip opening quote
            local startPos = pos
            local closed = false
            while pos <= len do
                if line:sub(pos, pos) == '"' then
                    if pos + 1 <= len and line:sub(pos + 1, pos + 1) == '"' then
                        -- Escaped quote ""
                        value = value .. line:sub(startPos, pos)
                        pos = pos + 2
                        startPos = pos
                    else
                        -- Closing quote
                        value = value .. line:sub(startPos, pos - 1)
                        pos = pos + 1 -- skip closing quote
                        closed = true
                        -- Skip comma after closing quote
                        if pos <= len and line:sub(pos, pos) == "," then
                            pos = pos + 1
                        end
                        break
                    end
                else
                    pos = pos + 1
                end
            end
            -- Unterminated quote: take the rest as value
            if not closed then
                value = value .. line:sub(startPos)
            end
            table.insert(fields, value)
        else
            -- Unquoted field
            local nextComma = line:find(",", pos)
            if nextComma then
                table.insert(fields, line:sub(pos, nextComma - 1))
                pos = nextComma + 1
            else
                table.insert(fields, line:sub(pos))
                pos = len + 1
            end
        end
    end

    -- Handle trailing comma
    if len > 0 and line:sub(len, len) == "," then
        table.insert(fields, "")
    end

    return fields
end

-- Parse full CSV text, returns list of wishlist entries
function TMBExport:ParseCSV(csvText)
    local entries = {}
    local headers = nil
    local lineNum = 0

    for line in csvText:gmatch("[^\r\n]+") do
        lineNum = lineNum + 1
        line = trim(line)
        if line ~= "" then
            local fields = ParseCSVLine(line)

            if not headers then
                -- First line is headers
                headers = {}
                for i, h in ipairs(fields) do
                    headers[i] = trim(h)
                end
            else
                -- Data line: map fields to header names
                local row = {}
                for i, h in ipairs(headers) do
                    row[h] = fields[i] and trim(fields[i]) or ""
                end

                -- Only import wishlist entries (not "received").
                -- Entries without instance_name are kept: tier set pieces have
                -- no instance/source in the CSV and are remapped to their token
                -- (with instance + source) at import time by RemapTierPieces.
                if row["type"] == "wishlist" then
                    local entry = {
                        raid_group_name = (row["raid_group_name"] ~= nil and row["raid_group_name"] ~= "") and row["raid_group_name"] or "No Roster",
                        character_name = row["character_name"] or "",
                        character_class = row["character_class"] or "",
                        member_name = row["member_name"] or "",
                        sort_order = tonumber(row["sort_order"]) or 99,
                        item_name = row["item_name"] or "",
                        item_id = tonumber(row["item_id"]) or 0,
                        is_offspec = (row["is_offspec"] == "1"),
                        instance_name = row["instance_name"] or "",
                        source_name = row["source_name"] or "",
                        received_at = row["received_at"] or "",
                        note = row["note"] or "",
                    }
                    table.insert(entries, entry)
                end
            end
        end
    end

    return entries
end
