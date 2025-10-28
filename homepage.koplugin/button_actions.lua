local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local ReaderUI = require("apps/reader/readerui")
local logger = require("logger")
local _ = require("gettext")

local ButtonActions = {}

function ButtonActions:openBook(filepath, homepage_widget)
    if homepage_widget then
        UIManager:close(homepage_widget)
    end
    ReaderUI:showReader(filepath)
end

function ButtonActions:showFrontlight(ui)
    ui:handleEvent(require("ui/event"):new("ShowFlDialog"))
end

function ButtonActions:showHistory(ui, homepage_widget)
    UIManager:close(homepage_widget)
    
    if ui.document then
        -- Если открыта книга, закрываем её и показываем историю
        UIManager:scheduleIn(0.1, function()
            ui:onClose()
            UIManager:scheduleIn(0.1, function()
                local FileManager = require("apps/filemanager/filemanager")
                if FileManager.instance and FileManager.instance.history then
                    FileManager.instance.history:onShowHist()
                else
                    FileManager:showFiles()
                    UIManager:scheduleIn(0.1, function()
                        if FileManager.instance and FileManager.instance.history then
                            FileManager.instance.history:onShowHist()
                        end
                    end)
                end
            end)
        end)
    else
        -- Если в файловом менеджере
        local FileManager = require("apps/filemanager/filemanager")
        if FileManager.instance and FileManager.instance.history then
            FileManager.instance.history:onShowHist()
        else
            -- Если FileManager не запущен, запускаем его сначала
            FileManager:showFiles()
            UIManager:scheduleIn(0.1, function()
                if FileManager.instance and FileManager.instance.history then
                    FileManager.instance.history:onShowHist()
                end
            end)
        end
    end
end

function ButtonActions:showFiles(ui, homepage_widget)
    UIManager:close(homepage_widget)
    
    if ui.document then
        local FileManager = require("apps/filemanager/filemanager")
        UIManager:scheduleIn(0.1, function()
            ui:onClose()
            if not FileManager.instance then
                FileManager:showFiles()
            end
        end)
    else
        local FileManager = require("apps/filemanager/filemanager")
        if FileManager.instance and FileManager.instance.file_chooser then
            FileManager.instance.file_chooser:refreshPath()
        end
    end
end

function ButtonActions:toggleCalibre()
    
    local ok, CalibreWireless = pcall(require, "wireless")
    
    if ok and CalibreWireless then
        
        if CalibreWireless.calibre_socket then
            CalibreWireless:disconnect()
        else
            CalibreWireless:connect()
        end
    else
        logger.warn("[HomePage] Failed to load CalibreWireless module:", CalibreWireless)
        UIManager:show(InfoMessage:new{
            text = _("Calibre plugin not available. Please enable it in Tools → Plugin management"),
        })
    end
end

function ButtonActions:toggleWifi(callback)
    local NetworkMgr = require("ui/network/manager")
    if NetworkMgr:isWifiOn() then
        NetworkMgr:turnOffWifi(callback)
    else
        NetworkMgr:turnOnWifi(callback)
    end
end

function ButtonActions:showFavorites(ui, homepage_widget)
    UIManager:close(homepage_widget)
    if ui.collections then
        ui.collections:onShowColl()
    else
        UIManager:show(InfoMessage:new{
            text = _("Collections not available. Please make sure ReadCollection plugin is enabled."),
        })
    end
end

function ButtonActions:showCollections(ui, homepage_widget)
    UIManager:close(homepage_widget)
    if ui.collections then
        ui.collections:onShowCollList()
    else
        UIManager:show(InfoMessage:new{
            text = _("Collections not available. Please make sure ReadCollection plugin is enabled."),
        })
    end
end

function ButtonActions:exitApp(homepage_widget)
    UIManager:close(homepage_widget)
    UIManager:scheduleIn(0.1, function()
        local Event = require("ui/event")
        UIManager:broadcastEvent(Event:new("Exit"))
    end)
end

return ButtonActions