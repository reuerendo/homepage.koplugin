local DataStorage = require("datastorage")
local DocSettings = require("docsettings")
local DocumentRegistry = require("document/documentregistry")
local ReadHistory = require("readhistory")
local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")

local DocumentManager = {}

function DocumentManager:getLastDocument()
    ReadHistory:ensureLastFile()
    local last_file = ReadHistory.last_file
    
    if not last_file and ReadHistory.hist and #ReadHistory.hist > 0 then
        last_file = ReadHistory.hist[1].file
    end
    
    if not last_file then
        local G_reader_settings = require("luasettings"):open(DataStorage:getDataDir().."/settings.reader.lua")
        last_file = G_reader_settings:readSetting("lastfile")
    end
    
    if not last_file then
        return nil
    end
    
    local doc_settings = DocSettings:open(last_file)
    local props = doc_settings:readSetting("doc_props") or {}
    
    return {
        file = last_file,
        props = props,
        settings = doc_settings,
    }
end

function DocumentManager:getCoverImage(doc_info)
    logger.dbg("[HomePage] Starting cover search for:", doc_info.file)
    
    -- 1. Custom cover
    local custom_cover = DocSettings:findCustomCoverFile(doc_info.file)
    if custom_cover and lfs.attributes(custom_cover, "mode") == "file" then
        logger.dbg("[HomePage] ✓ Custom cover found:", custom_cover)
        return custom_cover
    end
    
    -- 2. Cached cover
    local cover_file = doc_info.settings:readSetting("cover_file")
    if cover_file and lfs.attributes(cover_file, "mode") == "file" then
        logger.dbg("[HomePage] ✓ Cached cover file:", cover_file)
        return cover_file
    end
    
    -- 3. BookInfoManager cache
    local ok_bim, BookInfoManager = pcall(require, "bookinfomanager")
    if ok_bim then
        local ok, bookinfo = pcall(BookInfoManager.getBookInfo, BookInfoManager, doc_info.file, true)
        
        if ok and bookinfo and bookinfo.cover_bb then
            logger.dbg("[HomePage] ✓ Cover found in BookInfoManager cache (BlitBuffer)")
            return bookinfo.cover_bb
        end
    end
    
    -- 4. Extract from document
    if DocumentRegistry:hasProvider(doc_info.file) then
        logger.dbg("[HomePage] Extracting cover from document")
        local ok_doc, doc = pcall(DocumentRegistry.openDocument, DocumentRegistry, doc_info.file)
        
        if ok_doc and doc then
            local ok_cover, cover = pcall(function()
                return doc:getCoverPageImage()
            end)
            doc:close()
            
            if ok_cover and cover then
                logger.dbg("[HomePage] ✓ Cover extracted from document")
                return cover
            end
        end
    end
    
    logger.dbg("[HomePage] ✗ No cover found")
    return nil
end

function DocumentManager:getPageCount(doc_settings)
    -- Check pocketbook_sync_progress first
    local pb_sync = doc_settings:readSetting("pocketbook_sync_progress")
    if pb_sync and pb_sync.total_pages then
        logger.dbg("[DocumentManager] Using page count from pocketbook_sync_progress:", pb_sync.total_pages)
        return pb_sync.total_pages
    end
    
    -- Fallback to standard methods
    local doc_pages = doc_settings:readSetting("doc_pages")
    if doc_pages then
        return doc_pages
    end
    
    local stats = doc_settings:readSetting("stats")
    if stats and stats.pages then
        return stats.pages
    end
    
    return nil
end

function DocumentManager:getReadingProgress(doc_settings)
    -- Check pocketbook_sync_progress first
    local pb_sync = doc_settings:readSetting("pocketbook_sync_progress")
    if pb_sync and pb_sync.percent then
        logger.dbg("[DocumentManager] Using reading progress from pocketbook_sync_progress:", pb_sync.percent)
        return pb_sync.percent
    end
    
    -- Fallback to standard methods
    local percent = doc_settings:readSetting("percent_finished")
    if percent then
        return math.floor(percent * 100)
    end
    
    local summary = doc_settings:readSetting("summary")
    if summary and summary.percent then
        return math.floor(summary.percent)
    end
    
    return 0
end

function DocumentManager:getCurrentPage(doc_settings)
    -- Check pocketbook_sync_progress first
    local pb_sync = doc_settings:readSetting("pocketbook_sync_progress")
    if pb_sync and pb_sync.current_page then
        logger.dbg("[DocumentManager] Using current page from pocketbook_sync_progress:", pb_sync.current_page)
        return pb_sync.current_page
    end
    
    -- Fallback to standard method
    local last_xpointer = doc_settings:readSetting("last_xpointer")
    if last_xpointer then
        -- This would require document to be opened to convert xpointer to page
        -- For now, return nil if pocketbook_sync_progress is not available
        return nil
    end
    
    return nil
end

function DocumentManager:getSummary(doc_settings)
    local summary = doc_settings:readSetting("summary")
    if not summary then
        summary = {
            rating = 0,
            status = "reading",
            note = "",
            modified = os.date("%Y-%m-%d", os.time())
        }
    end
    return summary
end

return DocumentManager