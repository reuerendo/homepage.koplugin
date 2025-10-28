local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local datetime = require("datetime")
local DocSettings = require("docsettings")
local DataStorage = require("datastorage")
local SQ3 = require("lua-ljsqlite3/init")
local util = require("util")
local logger = require("logger")
local _ = require("gettext")

local Screen = Device.screen

local ReadingStatistics = {}

local db_location = DataStorage:getSettingsDir() .. "/statistics.sqlite3"

local STATISTICS_SQL_BOOK_TOTALS_QUERY = [[
    SELECT count(DISTINCT page),
           sum(duration)
    FROM   page_stat
    WHERE  id_book = %d;
]]

function ReadingStatistics:getStatsBook(doc_info)
    local stats = {
        time = nil,
        days = nil,
        pages = nil
    }
    
    if not doc_info or not doc_info.file then
        logger.warn("ReadingStatistics: doc_info or file is nil")
        return stats
    end
    
    -- Get doc_settings
    local doc_settings
    if doc_info.settings then
        doc_settings = doc_info.settings
    else
        doc_settings = DocSettings:open(doc_info.file)
    end
    
    if not doc_settings then
        logger.warn("ReadingStatistics: Could not get doc_settings")
        return stats
    end
    
    -- Check pocketbook_sync_progress for pages count
    local pb_sync = doc_settings:readSetting("pocketbook_sync_progress")
    if pb_sync and pb_sync.current_page then
        logger.dbg("ReadingStatistics: Using pages from pocketbook_sync_progress:", pb_sync.current_page)
        stats.pages = pb_sync.current_page
        
        -- Try to get time and days from database anyway
        local doc_md5 = doc_settings:readSetting("partial_md5_checksum")
        if not doc_md5 then
            doc_md5 = util.partialMD5(doc_info.file)
        end
        
        local doc_stats = doc_settings:readSetting("stats")
        local title = doc_info.props and doc_info.props.title
        local authors = doc_info.props and doc_info.props.authors
        
        if not title and doc_stats then
            title = doc_stats.title
        end
        if not authors and doc_stats then
            authors = doc_stats.authors
        end
        
        if not title then
            title = doc_info.file:match("([^/]+)$")
        end
        if not authors then
            authors = "N/A"
        end
        
        local conn = SQ3.open(db_location)
        if conn then
            local sql_stmt = [[
                SELECT id
                FROM   book
                WHERE  title = ?
                  AND  authors = ?
                  AND  md5 = ?;
            ]]
            
            local stmt = conn:prepare(sql_stmt)
            local result = stmt:reset():bind(title, authors, doc_md5):step()
            
            if result then
                local id_book = tonumber(result[1])
                stmt:close()
                
                -- Get statistics by days
                sql_stmt = [[
                    SELECT count(*)
                    FROM   (
                                SELECT strftime('%%Y-%%m-%%d', start_time, 'unixepoch', 'localtime') AS dates
                                FROM   page_stat
                                WHERE  id_book = %d
                                GROUP  BY dates
                           );
                ]]
                local total_days = conn:rowexec(string.format(sql_stmt, id_book))
                
                -- Get total time
                local _, total_time_book = conn:rowexec(string.format(STATISTICS_SQL_BOOK_TOTALS_QUERY, id_book))
                
                if total_days and tonumber(total_days) > 0 then
                    stats.days = tonumber(total_days)
                end
                
                if total_time_book and tonumber(total_time_book) > 0 then
                    stats.time = tonumber(total_time_book)
                end
            else
                stmt:close()
            end
            
            conn:close()
        end
        
        return stats
    end
    
    -- Standard database lookup
    local doc_md5 = doc_settings:readSetting("partial_md5_checksum")
    if not doc_md5 then
        doc_md5 = util.partialMD5(doc_info.file)
    end
    
    -- Get book metadata
    local doc_stats = doc_settings:readSetting("stats")
    local title = doc_info.props and doc_info.props.title
    local authors = doc_info.props and doc_info.props.authors
    
    if not title and doc_stats then
        title = doc_stats.title
    end
    if not authors and doc_stats then
        authors = doc_stats.authors
    end
    
    if not title then
        title = doc_info.file:match("([^/]+)$")
    end
    if not authors then
        authors = "N/A"
    end
    
    -- Open database and search for book
    local conn = SQ3.open(db_location)
    if not conn then
        logger.warn("ReadingStatistics: Cannot open database")
        return stats
    end
    
    -- Search book by title, authors and md5
    local sql_stmt = [[
        SELECT id
        FROM   book
        WHERE  title = ?
          AND  authors = ?
          AND  md5 = ?;
    ]]
    
    local stmt = conn:prepare(sql_stmt)
    local result = stmt:reset():bind(title, authors, doc_md5):step()
    
    local id_book
    if result then
        id_book = tonumber(result[1])
    else
        logger.warn("ReadingStatistics: Book not found in database")
        stmt:close()
        conn:close()
        
        -- Try to get pages from doc_settings
        if doc_stats and doc_stats.pages then
            stats.pages = tonumber(doc_stats.pages)
        end
        
        return stats
    end
    
    stmt:close()
    
    -- Get statistics by days
    sql_stmt = [[
        SELECT count(*)
        FROM   (
                    SELECT strftime('%%Y-%%m-%%d', start_time, 'unixepoch', 'localtime') AS dates
                    FROM   page_stat
                    WHERE  id_book = %d
                    GROUP  BY dates
               );
    ]]
    local total_days = conn:rowexec(string.format(sql_stmt, id_book))
    
    -- Get total time and pages
    local total_read_pages, total_time_book = conn:rowexec(string.format(STATISTICS_SQL_BOOK_TOTALS_QUERY, id_book))
    
    conn:close()
    
    -- Fill results
    if total_days and tonumber(total_days) > 0 then
        stats.days = tonumber(total_days)
    end
    
    if total_time_book and tonumber(total_time_book) > 0 then
        stats.time = tonumber(total_time_book)
    end
    
    if total_read_pages and tonumber(total_read_pages) > 0 then
        stats.pages = tonumber(total_read_pages)
    elseif doc_stats and doc_stats.pages then
        stats.pages = tonumber(doc_stats.pages)
    end
    
    return stats
end

function ReadingStatistics:getStatDays(stats_book)
    if stats_book and stats_book.days and type(stats_book.days) == "number" then
        return tostring(stats_book.days)
    else
        return _("N/A")
    end
end

function ReadingStatistics:getStatHours(stats_book)
    if stats_book and stats_book.time and type(stats_book.time) == "number" then
        local user_duration_format = G_reader_settings:readSetting("duration_format", "classic")
        return datetime.secondsToClockDuration(user_duration_format, stats_book.time, false)
    else
        return _("N/A")
    end
end

function ReadingStatistics:getStatReadPages(stats_book, total_pages)
    if stats_book and stats_book.pages and type(stats_book.pages) == "number" then
        local pages_text = tostring(stats_book.pages)
        if total_pages and type(total_pages) == "number" and total_pages > 0 then
            return string.format("%s/%s", pages_text, tostring(total_pages))
        else
            return pages_text
        end
    else
        return _("N/A")
    end
end

function ReadingStatistics:buildStatisticsWidget(doc_info, width, total_pages)
    local stats_book = self:getStatsBook(doc_info)
    
    local height = Screen:scaleBySize(60)
    local small_font_face = Font:getFace("smallffont")
    local medium_font_face = Font:getFace("ffont")
    
    local tile_width = width * (1/3)
    local tile_height = height * (1/2)
    
    -- Title row
    local titles_group = HorizontalGroup:new{
        align = "center",
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = _("Days"),
                face = small_font_face,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = _("Time"),
                face = small_font_face,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = _("Read pages"),
                face = small_font_face,
            }
        }
    }
    
    -- Data row
    local data_group = HorizontalGroup:new{
        align = "center",
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = self:getStatDays(stats_book),
                face = medium_font_face,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = self:getStatHours(stats_book),
                face = medium_font_face,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = self:getStatReadPages(stats_book, total_pages),
                face = medium_font_face,
            }
        }
    }
    
    local statistics_group = VerticalGroup:new{
        align = "left",
        titles_group,
        data_group,
    }
    
    return CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
        statistics_group,
    }
end

return ReadingStatistics