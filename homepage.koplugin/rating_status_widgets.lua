local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local ToggleSwitch = require("ui/widget/toggleswitch")
local UIManager = require("ui/uimanager")
local util = require("util")
local _ = require("gettext")

local DocumentManager = require("document_manager")

local Screen = Device.screen

local RatingStatusWidgets = {}

-- Helper function to get the active DocSettings instance
local function getActiveDocSettings(file_path, provided_settings)
    local ReaderUI = require("apps/reader/readerui")
    if ReaderUI.instance and ReaderUI.instance.document then
        if ReaderUI.instance.document.file == file_path then
            return ReaderUI.instance.doc_settings or ReaderUI.instance.document.configurable
        end
    end
    return provided_settings
end

function RatingStatusWidgets:setStar(num, doc_info, stars_container, homepage_widget)
    stars_container:clear()

    local doc_settings = getActiveDocSettings(doc_info.file, doc_info.settings)
    local summary = doc_settings:readSetting("summary") or {}

    -- Toggle rating: if clicking the same rating, set to 0
    if num == summary.rating then
        num = 0
    end

    summary.rating = num
    summary.modified = os.date("%Y-%m-%d", os.time())

    doc_settings:saveSetting("summary", summary)
    doc_settings:flush()

    -- Also save to original doc_info.settings if different
    if doc_settings ~= doc_info.settings then
        doc_info.settings:saveSetting("summary", summary)
        doc_info.settings:flush()
    end

    -- Invalidate BookInfoManager cache
    local ok_bim, BookInfoManager = pcall(require, "bookinfomanager")
    if ok_bim then
        pcall(function() BookInfoManager:deleteBookInfo(doc_info.file) end)
    end

    -- Recreate star buttons with updated rating
    local stars_group = HorizontalGroup:new{ align = "center" }

    local star_base = Button:new{
        icon = "star.empty",
        bordersize = 0,
        radius = 0,
        margin = 0,
        enabled = true,
        show_parent = homepage_widget,
    }

    for i = 1, num do
        local star = star_base:new{
            icon = "star.full",
            callback = function()
                self:setStar(i, doc_info, stars_container, homepage_widget)
            end
        }
        table.insert(stars_group, star)
    end

    for i = num + 1, 5 do
        local star = star_base:new{
            callback = function()
                self:setStar(i, doc_info, stars_container, homepage_widget)
            end
        }
        table.insert(stars_group, star)
    end

    table.insert(stars_container, stars_group)
    UIManager:setDirty(homepage_widget, "ui")
end

function RatingStatusWidgets:generateRatingWidget(doc_info, info_width, homepage_widget)
    local summary = DocumentManager:getSummary(doc_info.settings)
    local rating = summary.rating or 0

    local stars_container = CenterContainer:new{
        dimen = Geom:new{ w = info_width, h = Screen:scaleBySize(60) },
    }

    local stars_group = HorizontalGroup:new{ align = "center" }

    local star_base = Button:new{
        icon = "star.empty",
        bordersize = 0,
        radius = 0,
        margin = 0,
        enabled = true,
        show_parent = homepage_widget,
    }

    for i = 1, rating do
        local star = star_base:new{
            icon = "star.full",
            callback = function()
                self:setStar(i, doc_info, stars_container, homepage_widget)
            end
        }
        table.insert(stars_group, star)
    end

    for i = rating + 1, 5 do
        local star = star_base:new{
            callback = function()
                self:setStar(i, doc_info, stars_container, homepage_widget)
            end
        }
        table.insert(stars_group, star)
    end

    table.insert(stars_container, stars_group)

    return stars_container
end

function RatingStatusWidgets:onChangeBookStatus(args, position, doc_info, homepage_widget)
    local doc_settings = getActiveDocSettings(doc_info.file, doc_info.settings)
    local summary = doc_settings:readSetting("summary") or {}

    summary.status = args[position]
    summary.modified = os.date("%Y-%m-%d", os.time())

    doc_settings:saveSetting("summary", summary)
    doc_settings:flush()

    -- Also save to original doc_info.settings if different
    if doc_settings ~= doc_info.settings then
        doc_info.settings:saveSetting("summary", summary)
        doc_info.settings:flush()
    end

    -- Invalidate BookInfoManager cache
    local ok_bim, BookInfoManager = pcall(require, "bookinfomanager")
    if ok_bim then
        pcall(function() BookInfoManager:deleteBookInfo(doc_info.file) end)
    end

    UIManager:setDirty(homepage_widget, "ui")
end

function RatingStatusWidgets:generateStatusWidget(doc_info, info_width, homepage_widget)
    local summary = DocumentManager:getSummary(doc_info.settings)

    local config_wrapper = {
        rating_status = self,
        doc_info = doc_info,
        homepage_widget = homepage_widget,
    }

    function config_wrapper:onConfigChoose(values, name, event, args, position)
        UIManager:tickAfterNext(function()
            self.rating_status:onChangeBookStatus(args, position, self.doc_info, self.homepage_widget)
        end)
    end

    local switch = ToggleSwitch:new{
        width = info_width,
        toggle = { _("Reading"), _("On hold"), _("Finished"), },
        args = { "reading", "abandoned", "complete", },
        values = { 1, 2, 3, },
        enabled = true,
        config = config_wrapper,
    }

    local position = util.arrayContains(switch.args, summary.status) or 1
    switch:setPosition(position)

    local height = Screen:scaleBySize(80)

    return CenterContainer:new{
        dimen = Geom:new{ w = info_width, h = height },
        switch,
    }
end

function RatingStatusWidgets:generateRatingWidgetCompact(doc_info, info_width, homepage_widget)
    local summary = DocumentManager:getSummary(doc_info.settings)
    local rating = summary.rating or 0

    local stars_container = HorizontalGroup:new{ align = "center" }

    local star_base = Button:new{
        icon = "star.empty",
        bordersize = 0,
        radius = 0,
        margin = 0,
        enabled = true,
        show_parent = homepage_widget,
    }

    for i = 1, rating do
        local star = star_base:new{
            icon = "star.full",
            callback = function()
                self:setStar(i, doc_info, stars_container, homepage_widget)
            end
        }
        table.insert(stars_container, star)
    end

    for i = rating + 1, 5 do
        local star = star_base:new{
            callback = function()
                self:setStar(i, doc_info, stars_container, homepage_widget)
            end
        }
        table.insert(stars_container, star)
    end

    return stars_container
end

function RatingStatusWidgets:generateStatusWidgetCompact(doc_info, info_width, homepage_widget)
    local summary = DocumentManager:getSummary(doc_info.settings)

    local config_wrapper = {
        rating_status = self,
        doc_info = doc_info,
        homepage_widget = homepage_widget,
    }

    function config_wrapper:onConfigChoose(values, name, event, args, position)
        UIManager:tickAfterNext(function()
            self.rating_status:onChangeBookStatus(args, position, self.doc_info, self.homepage_widget)
        end)
    end

    local switch = ToggleSwitch:new{
        width = info_width,
        toggle = { _("Reading"), _("On hold"), _("Finished"), },
        args = { "reading", "abandoned", "complete", },
        values = { 1, 2, 3, },
        enabled = true,
        config = config_wrapper,
    }

    local position = util.arrayContains(switch.args, summary.status) or 1
    switch:setPosition(position)

    return switch
end

return RatingStatusWidgets