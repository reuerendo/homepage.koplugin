local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Dispatcher = require("dispatcher")
local ffiUtil = require("ffi/util")
local logger = require("logger")
local _ = require("gettext")
local T = ffiUtil.template
local DocumentManager = require("document_manager")
local UIBuilder = require("ui_builder")

-- Patch for adding "Show home page" to document end actions
local original_dofile = dofile
local homepage_patch_applied = false
_G.dofile = function(filepath)
    local result = original_dofile(filepath)
    
    if not homepage_patch_applied and filepath and filepath:match("common_settings_menu_table%.lua$") then
        if result and result.document_end_action then
            local sub_table = result.document_end_action.sub_item_table
            if sub_table then
                table.insert(sub_table, 2, {
                    text = _("Show home page"),
                    checked_func = function()
                        return G_reader_settings:readSetting("end_document_action") == "show_homepage"
                    end,
                    radio = true,
                    callback = function()
                        G_reader_settings:saveSetting("end_document_action", "show_homepage")
                    end,
                })
                homepage_patch_applied = true
            end
        end
    end
    
    return result
end

local HomePage = WidgetContainer:extend{
    name = "homepage",
    is_doc_only = false,
}

if not _G.KOREADER_STARTED then
    _G.KOREADER_STARTED = true
    _G.KOREADER_COLD_START = true
else
    _G.KOREADER_COLD_START = false
end

function HomePage:init()
    self.ui.menu:registerToMainMenu(self)
    self:onDispatcherRegisterActions()
    self:patchStartWithMenu()
    
    local start_with = G_reader_settings:readSetting("start_with")
    
    if start_with == "homepage" and _G.KOREADER_COLD_START and not HomePage.startup_action_performed then
        _G.KOREADER_COLD_START = false
        
        UIManager:scheduleIn(0, function()
            if HomePage.startup_action_performed then return end

            local FileManager = require("apps/filemanager/filemanager")
            if self.ui == FileManager.instance then
                HomePage.startup_action_performed = true
                self:showAtStartup()
            end
        end)
    end
end

function HomePage:onDispatcherRegisterActions()
    Dispatcher:registerAction("show_homepage", {
        category = "none",
        event = "ShowHomePage",
        title = _("Show Home Page"),
        general = true,
        filemanager = true,
        reader = true,
    })
end

function HomePage:patchStartWithMenu()
    local FileManagerMenu = require("apps/filemanager/filemanagermenu")
    
    if not FileManagerMenu._homepage_patched then
        FileManagerMenu._homepage_patched = true
        
        local original_getStartWithMenuTable = FileManagerMenu.getStartWithMenuTable
        
        FileManagerMenu.getStartWithMenuTable = function(menu_self)
            local result = original_getStartWithMenuTable(menu_self)
            
            table.insert(result.sub_item_table, {
                text = _("Home Page"),
                checked_func = function()
                    return G_reader_settings:readSetting("start_with") == "homepage"
                end,
                callback = function()
                    G_reader_settings:saveSetting("start_with", "homepage")
                end,
            })
            
            local original_text_func = result.text_func
            result.text_func = function()
                local start_with = G_reader_settings:readSetting("start_with")
                if start_with == "homepage" then
                    return T(_("Start with: %1"), _("home page"))
                end
                return original_text_func()
            end
            
            return result
        end
    end
end

function HomePage:addToMainMenu(menu_items)
    menu_items.homepage = {
        text = _("Home Page"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text = _("Show Home Page"),
                callback = function()
                    self:show()
                end,
            },
        },
    }
end

function HomePage:onShowHomePage()
    local current_file = self.ui.document and self.ui.document.file
    self:show(current_file)
    return true
end

function HomePage:showAtStartup()
    local doc_info = DocumentManager:getLastDocument()
    
    if not doc_info then
        UIManager:show(InfoMessage:new{
            text = _("No document found in history"),
        })
        return
    end
    
    self:show(nil)
end

function HomePage:show(file_path)
    if self.homepage_widget then
        UIManager:close(self.homepage_widget, "full")
        self.homepage_widget = nil
    end
    
    local doc_info
    
    if file_path then
        local DocSettings = require("docsettings")
        local doc_settings = DocSettings:open(file_path)
        local props = doc_settings:readSetting("doc_props") or {}
        
        doc_info = {
            file = file_path,
            props = props,
            settings = doc_settings,
        }
    else
        doc_info = DocumentManager:getLastDocument()
    end
    
    if not doc_info then
        UIManager:show(InfoMessage:new{
            text = _("No document found in history"),
        })
        return
    end
    
    self.homepage_widget = UIBuilder:buildHomePage(self, doc_info)
    
    self.homepage_widget.covers_fullscreen = true
    self.homepage_widget.dithered = true
    
    self.homepage_widget.onClose = function()
        self.homepage_widget = nil
    end
    
    UIManager:show(self.homepage_widget, "full")
end

function HomePage:onCloseDocument()
    if self.homepage_widget then
        UIManager:close(self.homepage_widget, "full")
        self.homepage_widget = nil
    end
end

function HomePage:onEndOfBook()
    local end_action = G_reader_settings:readSetting("end_document_action")
    
    if end_action == "show_homepage" then
        local current_file = self.ui.document and self.ui.document.file
        self:show(current_file)
        return true
    end
end

return HomePage