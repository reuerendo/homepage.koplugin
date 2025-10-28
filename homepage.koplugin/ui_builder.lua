local ffi = require("ffi")
local Blitbuffer = require("ffi/blitbuffer")
local Button = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local ProgressWidget = require("ui/widget/progresswidget")
local RightContainer = require("ui/widget/container/rightcontainer")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local InputContainer = require("ui/widget/container/inputcontainer")

local DocumentManager = require("document_manager")
local RatingStatusWidgets = require("rating_status_widgets")
local ButtonActions = require("button_actions")
local ReadingStatistics = require("reading_statistics")

local Screen = Device.screen

local UIBuilder = {}

function UIBuilder:buildCoverWidget(doc_info, cover_width, cover_height, homepage_instance)
    local cover_image = DocumentManager:getCoverImage(doc_info)
    local cover_widget
    
    if cover_image then
        if type(cover_image) == "string" then
            cover_widget = ImageWidget:new{
                file = cover_image,
                width = cover_width,
                height = cover_height,
                scale_factor = 0,
            }
        else
            cover_widget = ImageWidget:new{
                image = cover_image,
                width = cover_width,
                height = cover_height,
                scale_factor = 0,
            }
        end
    else
        cover_widget = FrameContainer:new{
            width = cover_width,
            height = cover_height,
            background = Blitbuffer.COLOR_LIGHT_GRAY,
            bordersize = Size.border.thick,
            padding = 0,
            margin = 0,
            CenterContainer:new{
                dimen = Geom:new{
                    w = cover_width,
                    h = cover_height,
                },
                TextWidget:new{
                    text = _("No Cover"),
                    face = Font:getFace("cfont", 22),
                }
            }
        }
    end
    
    local cover_container = InputContainer:new{
        cover_widget,
    }
    
    cover_container.ges_events = {
        Tap = {
            GestureRange:new{
                ges = "tap",
                range = Geom:new{
                    x = 0, y = 0,
                    w = cover_width,
                    h = cover_height,
                }
            }
        }
    }
    
    function cover_container:onTap()
        ButtonActions:openBook(doc_info.file, homepage_instance.homepage_widget)
        return true
    end
    
    return cover_container
end

function UIBuilder:buildInfoPanel(doc_info, info_width, cover_height, homepage_widget)
    local title = doc_info.props.title or doc_info.file:match("([^/]+)$")
    local authors = doc_info.props.authors or _("Unknown Author")
    local series = doc_info.props.series
    local series_index = doc_info.props.series_index
    local percent_finished = DocumentManager:getReadingProgress(doc_info.settings)
    local page_count = DocumentManager:getPageCount(doc_info.settings)
    
    -- Block 1: Title, series, author (top)
    local block1_widgets = {}
    
    table.insert(block1_widgets, TextWidget:new{
        text = title,
        face = Font:getFace("infofont", 24),
        bold = true,
        max_width = info_width,
    })
    table.insert(block1_widgets, VerticalSpan:new{ width = Size.span.vertical_default })
    
	if series and series ~= "" then
		local series_text = series
		if series_index then
			series_text = series_text .. " — " .. tostring(series_index)
		end
		table.insert(block1_widgets, TextWidget:new{
			text = series_text,
			face = Font:getFace("xx_smallinfofont", 18),
			max_width = info_width,
		})
		table.insert(block1_widgets, VerticalSpan:new{ width = Size.span.vertical_default })
	end
    
    table.insert(block1_widgets, TextWidget:new{
        text = authors,
        face = Font:getFace("x_smallinfofont", 20),
        max_width = info_width,
    })
    
    local block1 = VerticalGroup:new{
        align = "left",
        unpack(block1_widgets)
    }
    
    -- Block 2: Page count and progress (center)
    local block2_widgets = {}
    
    if page_count then
        table.insert(block2_widgets, TextWidget:new{
            text = string.format(_("Pages: %d"), page_count),
            face = Font:getFace("xx_smallinfofont", 18),
            max_width = info_width,
        })
        table.insert(block2_widgets, VerticalSpan:new{ width = Size.span.vertical_default })
    end
    
    table.insert(block2_widgets, TextWidget:new{
        text = string.format(_("Progress: %d%%"), percent_finished),
        face = Font:getFace("xx_smallinfofont", 18),
        max_width = info_width,
    })
    table.insert(block2_widgets, VerticalSpan:new{ width = Size.span.vertical_default })
    
    table.insert(block2_widgets, ProgressWidget:new{
        width = info_width,
        height = Size.item.height_default / 2,
        percentage = percent_finished / 100,
        ticks = nil,
        last = nil,
    })
    
    local block2 = VerticalGroup:new{
        align = "left",
        unpack(block2_widgets)
    }
    
    -- Block 3: Rating and status (bottom) - compact widgets
    local block3_widgets = {}
    
    local rating_widget = RatingStatusWidgets:generateRatingWidgetCompact(doc_info, info_width, homepage_widget)
    local status_widget = RatingStatusWidgets:generateStatusWidgetCompact(doc_info, info_width, homepage_widget)
    
    -- Add padding below rating widget
    table.insert(block3_widgets, FrameContainer:new{
        padding = 0,
        padding_bottom = Size.padding.large,
        margin = 0,
        bordersize = 0,
        rating_widget,
    })
    table.insert(block3_widgets, VerticalSpan:new{ width = Size.span.vertical_default })
    table.insert(block3_widgets, status_widget)
    
    local block3 = VerticalGroup:new{
        align = "left",
        unpack(block3_widgets)
    }
    
    -- Calculate block heights
    local block1_height = block1:getSize().h
    local block2_height = block2:getSize().h
    local block3_height = block3:getSize().h
    
    -- Dynamic spacing calculation
    local total_content_height = block1_height + block2_height + block3_height
    local available_space = cover_height - total_content_height
    
    -- Distribute remaining space between blocks
    local spacing_between_blocks = math.max(Size.span.vertical_large, available_space / 2)
    
    -- Assemble with dynamic spacing
    local all_content = VerticalGroup:new{
        align = "left",
        block1,
        VerticalSpan:new{ width = spacing_between_blocks },
        block2,
        VerticalSpan:new{ width = spacing_between_blocks },
        block3,
    }
    
    return FrameContainer:new{
        padding = 0,
        margin = 0,
        bordersize = 0,
        width = info_width,
        height = cover_height,
        all_content,
    }
end

function UIBuilder:buildSectionHeader(title, width)
    local medium_font_face = Font:getFace("ffont")
    local spacing = Size.padding.default
    
    -- Header title widget
    local header_title = TextWidget:new{
        text = title,
        face = medium_font_face,
        fgcolor = Blitbuffer.COLOR_GRAY_9,
    }
    
    -- Calculate line width to fill available space
    local title_width = header_title:getSize().w
    local line_width = (width - title_width - spacing * 2) / 2
    
    -- Create line widgets
    local left_line = LineWidget:new{
        background = Blitbuffer.COLOR_LIGHT_GRAY,
        dimen = Geom:new{
            w = line_width,
            h = Size.line.thick,
        }
    }
    
    local right_line = LineWidget:new{
        background = Blitbuffer.COLOR_LIGHT_GRAY,
        dimen = Geom:new{
            w = line_width,
            h = Size.line.thick,
        }
    }
    
    -- Assemble header with title centered between lines
    local header = HorizontalGroup:new{
        align = "center",
        LeftContainer:new{
            dimen = Geom:new{ w = line_width, h = Size.item.height_default },
            left_line,
        },
        HorizontalSpan:new{ width = spacing },
        header_title,
        HorizontalSpan:new{ width = spacing },
        LeftContainer:new{
            dimen = Geom:new{ w = line_width, h = Size.item.height_default },
            right_line,
        },
    }
    
    return header
end

function UIBuilder:buildButtons(homepage_instance, doc_info, button_width, edge_padding)
    local function getWifiButtonText()
        local NetworkMgr = require("ui/network/manager")
        NetworkMgr:queryNetworkState()
        return NetworkMgr:isWifiOn() and _("Wi-Fi: On") or _("Wi-Fi: Off")
    end
    
    -- First row
    local frontlight_button = Button:new{
        text = _("Frontlight"),
        width = button_width,
        callback = function()
            ButtonActions:showFrontlight(homepage_instance.ui)
        end,
        bordersize = Size.border.button,
        padding = Size.padding.button,
        show_parent = homepage_instance,
    }
    
	local history_button = Button:new{
		text = _("History"),
		width = button_width,
		callback = function()
			ButtonActions:showHistory(homepage_instance.ui, homepage_instance.homepage_widget)
		end,
		bordersize = Size.border.button,
		padding = Size.padding.button,
		show_parent = homepage_instance,
	}
    
    local files_button = Button:new{
        text = _("Files"),
        width = button_width,
        callback = function()
            ButtonActions:showFiles(homepage_instance.ui, homepage_instance.homepage_widget)
        end,
        bordersize = Size.border.button,
        padding = Size.padding.button,
        show_parent = homepage_instance,
    }
    
    local calibre_button = Button:new{
        text = _("calibre"),
        width = button_width,
        callback = function()
            ButtonActions:toggleCalibre()
        end,
        bordersize = Size.border.button,
        padding = Size.padding.button,
        show_parent = homepage_instance,
    }
    
	local first_row = HorizontalGroup:new{
		align = "center",
		frontlight_button,
		HorizontalSpan:new{ width = edge_padding },
		history_button,
		HorizontalSpan:new{ width = edge_padding },
		files_button,
		HorizontalSpan:new{ width = edge_padding },
		calibre_button,
	}
    
    -- Second row
    local wifi_button
    wifi_button = Button:new{
        text = getWifiButtonText(),
        width = button_width,
        callback = function()
            ButtonActions:toggleWifi(function()
                wifi_button:setText(getWifiButtonText(), button_width)
                UIManager:setDirty(homepage_instance.homepage_widget, "ui")
            end)
        end,
        bordersize = Size.border.button,
        padding = Size.padding.button,
        show_parent = homepage_instance,
    }
    
    local favorites_button = Button:new{
        text = _("Favorites"),
        width = button_width,
        callback = function()
            ButtonActions:showFavorites(homepage_instance.ui, homepage_instance.homepage_widget)
        end,
        bordersize = Size.border.button,
        padding = Size.padding.button,
        show_parent = homepage_instance,
    }
    
    local collections_button = Button:new{
        text = _("Collections"),
        width = button_width,
        callback = function()
            ButtonActions:showCollections(homepage_instance.ui, homepage_instance.homepage_widget)
        end,
        bordersize = Size.border.button,
        padding = Size.padding.button,
        show_parent = homepage_instance,
    }
    
    local exit_button = Button:new{
        text = _("Exit"),
        width = button_width,
        callback = function()
            ButtonActions:exitApp(homepage_instance.homepage_widget)
        end,
        bordersize = Size.border.button,
        padding = Size.padding.button,
        show_parent = homepage_instance,
    }
    
    local second_row = HorizontalGroup:new{
        align = "center",
        wifi_button,
        HorizontalSpan:new{ width = edge_padding },
        favorites_button,
        HorizontalSpan:new{ width = edge_padding },
        collections_button,
        HorizontalSpan:new{ width = edge_padding },
        exit_button,
    }
    
    return first_row, second_row
end

function UIBuilder:buildTitleBar(homepage_widget, screen_width)
    -- Create TitleBar matching FileManager style
    local title_bar = TitleBar:new{
        width = screen_width,
        fullscreen = true,
        title = _("Homepage"),
        title_top_padding = Screen:scaleBySize(6),
        button_padding = Screen:scaleBySize(3),
        right_icon = "exit",
        right_icon_size_ratio = 1,
        right_icon_tap_callback = function()
            UIManager:close(homepage_widget, "ui")
        end,
        show_parent = homepage_widget,
    }
    
    return title_bar
end

function UIBuilder:buildHomePage(homepage_instance, doc_info)
    local screen_width = Screen:getWidth()
    local screen_height = Screen:getHeight()
    local edge_padding = Size.padding.large * 2
    
    -- Cover dimensions
    local cover_width = math.floor(screen_width * 0.4)
    local cover_height = math.floor(cover_width * 1.5)
    
    -- Info panel width
    local info_width = screen_width - cover_width - edge_padding * 3
    
    -- Build widgets
    local cover_container = self:buildCoverWidget(doc_info, cover_width, cover_height, homepage_instance)
    
    -- Create temporary widget reference for info panel
    local temp_widget = {}
    local info_container = self:buildInfoPanel(doc_info, info_width, cover_height, temp_widget)
    
    -- Main content layout
    local main_content = HorizontalGroup:new{
        align = "top",
        FrameContainer:new{
            padding = 0,
            margin = 0,
            bordersize = 0,
            cover_container,
        },
        HorizontalSpan:new{ width = edge_padding },
        info_container,
    }
    
    -- Statistics section with safe data retrieval
    local statistics_width = screen_width - edge_padding * 2
    
    -- Get total pages - try multiple sources
    local total_pages = DocumentManager:getPageCount(doc_info.settings)
    if not total_pages and doc_info.settings then
        local doc_stats = doc_info.settings:readSetting("stats")
        if doc_stats and doc_stats.total_pages then
            total_pages = doc_stats.total_pages
        end
    end
    total_pages = total_pages or 0
    
    -- Build statistics header and widget
    local statistics_header = self:buildSectionHeader(_("Statistics"), statistics_width)
    local statistics_widget = ReadingStatistics:buildStatisticsWidget(doc_info, statistics_width, total_pages)
    
    -- Separator line (same width as statistics_width)
    local separator = LineWidget:new{
        dimen = Geom:new{
            w = statistics_width,
            h = Size.line.thick,
        },
        background = Blitbuffer.COLOR_LIGHT_GRAY,
        style = "solid",
    }
    
    -- Buttons
    local button_width = math.floor((screen_width - edge_padding * 5) / 4)
    local first_row, second_row = self:buildButtons(homepage_instance, doc_info, button_width, edge_padding)
    
    local first_row_container = CenterContainer:new{
        dimen = Geom:new{
            w = screen_width - edge_padding * 2,
        },
        first_row,
    }
    
    local second_row_container = CenterContainer:new{
        dimen = Geom:new{
            w = screen_width - edge_padding * 2,
        },
        second_row,
    }
    
    -- ИЗМЕНЕНИЕ: Создаем homepage_widget как InputContainer вместо FrameContainer
    local homepage_widget = InputContainer:new{
        dimen = Geom:new{
            x = 0,
            y = 0,
            w = screen_width,
            h = screen_height,
        },
    }
    
    -- ДОБАВЛЕНИЕ: Регистрируем зону касания для свайпа
    homepage_widget:registerTouchZones({
        {
            id = "homepage_swipe_menu",
            ges = "swipe",
            screen_zone = {
                ratio_x = 0,
                ratio_y = 0,
                ratio_w = 1,
                ratio_h = 0.1,  -- Верхние 10% экрана
            },
            handler = function(ges)
                -- Проверяем направление свайпа
                if ges.direction == "south" then
                    -- Вызов меню файлового менеджера
                    if homepage_instance.ui and homepage_instance.ui.menu then
                        homepage_instance.ui.menu:onShowMenu()
                        return true
                    end
                end
                return false
            end,
        },
    })
    
    -- Create TitleBar (takes full screen width, no padding)
    local title_bar = self:buildTitleBar(homepage_widget, screen_width)
    local title_bar_height = title_bar:getHeight()
    
    -- Main body vertical layout (content below title bar with padding)
    local main_body = VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = edge_padding },
        main_content,
        VerticalSpan:new{ width = edge_padding * 2 },
        statistics_header,
        VerticalSpan:new{ width = Size.padding.default * 3 },
        statistics_widget,
        VerticalSpan:new{ width = edge_padding * 2 },
        separator,
        VerticalSpan:new{ width = edge_padding * 3 },
        first_row_container,
        VerticalSpan:new{ width = edge_padding * 3 },
        second_row_container,
    }
    
    -- Body with horizontal padding
    local body_with_padding = FrameContainer:new{
        padding = edge_padding,
        padding_top = 0,
        padding_bottom = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        width = screen_width,
        main_body,
    }
    
    -- Full content: TitleBar at top (full width) + padded body
    local full_content = VerticalGroup:new{
        align = "left",
        title_bar,
        body_with_padding,
    }
    
    -- ИЗМЕНЕНИЕ: Оборачиваем контент в FrameContainer перед добавлением в InputContainer
    local main_frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        width = screen_width,
        height = screen_height,
        full_content,
    }
    
    -- Update homepage_widget with final content
    homepage_widget[1] = main_frame
    
    -- Update temp widget reference
    temp_widget = homepage_widget
    
    function homepage_widget:onClose()
        UIManager:setDirty(self, function()
            return "full", self.dimen
        end)
        return true
    end
    
    return homepage_widget
end

return UIBuilder