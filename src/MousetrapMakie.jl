"""
Adds `GLMakieArea`, a widget that allows to render a Makie plot to a Mousetrap widget. 
"""
module MousetrapMakie

    export GLMakieArea, create_glmakie_screen, GtkGLMakieFigure

    using Mousetrap
    using ModernGL, GLMakie, Colors, GeometryBasics, ShaderAbstractions
    using GLMakie: empty_postprocessor, fxaa_postprocessor, OIT_postprocessor, to_screen_postprocessor
    using GLMakie.GLAbstraction
    using GLMakie.Makie
    """
    ## GLMakieArea <: Widget
    `GLArea` wrapper that automatically connects all necessary callbacks in order for it to be used as a GLMakie render target. 

    Use `create_glmakie_screen` to initialize a screen you can render to using Makie from this widget. Note that `create_glmakie_screen` needs to be 
    called **after** `GLMakieArea` has been realized, as only then will the internal OpenGL context be available. See the example below.

    ## Constructors
    `GLMakieArea()`

    ## Signals
    (no unique signals)

    ## Fields
    (no public fields)

    ## Example
    ```
    using Mousetrap, MousetrapMakie
    main() do app::Application
        window = Window(app)
        canvas = GLMakieArea()
        set_size_request!(canvas, Vector2f(200, 200))
        set_child!(window, canvas)
    
        # use optional ref to delay screen allocation after `realize`
        screen = Ref{Union{Nothing, GLMakie.Screen{GLMakieArea}}}(nothing)
        connect_signal_realize!(canvas) do self
            screen[] = create_glmakie_screen(canvas)
            display(screen[], scatter(1:4))
            return nothing
        end
        present!(window)
    end
    ```
    """
    mutable struct GLMakieArea <: Widget
        glarea::GLArea              # wrapped native widget
        framebuffer_id::Ref{Int}    # set by render callback, used in MousetrapMakie.create_glmakie_screen
        framebuffer_size::Vector2i  # set by resize callback, used in GLMakie.framebuffer_size
        scene::Scene
        screen::GLMakie.Screen{GLMakieArea}

        function GLMakieArea()
            gma = new()
            gma.framebuffer_id = Ref{Int}(0)
            gma.framebuffer_size = Vector2i(0, 0)
            
            glarea = GLArea()
            set_auto_render!(glarea, false) # should `render` be emitted everytime the widget is drawn
                  
            connect_signal_render!(
				function signal_render(self, ctx)
					screen = gma.screen
					if !isopen(screen) return false end
					screen.render_tick[] = Makie.BackendTick
					screen.glscreen.framebuffer_id[] = glGetIntegerv(GL_FRAMEBUFFER_BINDING)
					GLMakie.render_frame(screen) 
					return true
				end, glarea)

            connect_signal_resize!(
                function on_makie_area_resize(self, w, h)
                    events = gma.scene.events
                    screen = gma.screen

                    scale = screen.scalefactor[] / Mousetrap.get_scale_factor(gma)
                    w, h = round.(Int, (w, h) ./ scale )

                    gma.framebuffer_size.x = w
                    gma.framebuffer_size.y = h
                    ShaderAbstractions.switch_context!(gma)
    
                    events.window_area[] = Recti(minimum(events.window_area[]), w, h)
                    events.window_dpi[] = Mousetrap.calculate_monitor_dpi(gma)
            
                    queue_render(self) 
                    return nothing
                end, glarea)

            gma.glarea = glarea

            return gma
        end
    end

    Mousetrap.get_top_level_widget(x::GLMakieArea) = x.glarea

    # resolution of `GLMakieArea` OpenGL framebuffer
    GLMakie.framebuffer_size(self::GLMakieArea) = (self.framebuffer_size.x, self.framebuffer_size.y)

    # resolution of `GLMakieArea` widget itself`
    function GLMakie.window_size(w::GLMakieArea)
        size = get_natural_size(w)
        size.x = size.x * Mousetrap.get_scale_factor(w)
        size.y = size.y * Mousetrap.get_scale_factor(w)
        return (size.x, size.y)
    end

    # calculate screen size and dpi
    Makie.window_area(scene::Scene, screen::GLMakie.Screen{GLMakieArea}) = screen.glscreen.scene = scene

    # resize request by makie will be ignored
    function GLMakie.resize!(screen::GLMakie.Screen{GLMakieArea}, w::Int, h::Int)
        # noop
    end

    # bind `GLMakieArea` OpenGL context
    ShaderAbstractions.native_switch_context!(a::GLMakieArea) = make_current(a.glarea)

    # check if `GLMakieArea` OpenGL context is still valid, it is while `GLMakieArea` widget stays realized
    ShaderAbstractions.native_context_alive(x::GLMakieArea) = get_is_realized(x)

    # destruction callback ignored, lifetime is managed by mousetrap instead
    function GLMakie.destroy!(w::GLMakieArea)
        # noop
    end

    # check if canvas is still realized
    GLMakie.was_destroyed(window::GLMakieArea) = !get_is_realized(window)

    # check if canvas should signal it is open
    Base.isopen(w::GLMakieArea) = !GLMakie.was_destroyed(w)

    # react to makie screen visibility request
    GLMakie.set_screen_visibility!(screen::GLMakieArea, bool) = bool ? show(screen.glarea) : hide!(screen.glarea)

    # apply glmakie config
    function GLMakie.apply_config!(screen::GLMakie.Screen{GLMakieArea}, config::GLMakie.ScreenConfig; start_renderloop=true) 
        @warn "In MousetrapMakie: GLMakie.apply_config!: This feature is not yet implemented, ignoring config"
        # cf https://github.com/JuliaGtk/Gtk4Makie.jl/blob/main/src/screen.jl#L111
        return screen
    end

    # screenshot framebuffer
    function Makie.colorbuffer(screen::GLMakie.Screen{GLMakieArea}, format::Makie.ImageStorageFormat = Makie.JuliaNative)
        @warn "In MousetrapMakie: GLMakie.colorbuffer: This feature is not yet implemented, returning framecache"
        # cf https://github.com/JuliaGtk/Gtk4Makie.jl/blob/main/src/screen.jl#L147
        return screen.framecache
    end

    # ignore makie event model, use the mousetrap event controllers instead
    Makie.window_open(::Scene, ::GLMakieArea) = nothing
    Makie.disconnect!(::GLMakieArea, f) = nothing
	function GLMakie.pollevents(screen::GLMakie.Screen{GLMakieArea}, frame_state::Makie.TickState)
		screen.render_tick[] = frame_state
		return
	end
    Makie.mouse_buttons(::Scene, ::GLMakieArea) = nothing
    Makie.keyboard_buttons(::Scene, ::GLMakieArea) = nothing
    Makie.dropped_files(::Scene, ::GLMakieArea) = nothing
    Makie.unicode_input(::Scene, ::GLMakieArea) = nothing
    Makie.mouse_position(::Scene, ::GLMakie.Screen{GLMakieArea}) = nothing
    Makie.scroll(::Scene, ::GLMakieArea) = nothing
    Makie.hasfocus(::Scene, ::GLMakieArea) = nothing
    Makie.entered_window(::Scene, ::GLMakieArea) = nothing
	
	"""
		Wrap a figure in an area to display to a GLMakieArea and screen
	"""
	function GtkGLMakieFigure(fig::Figure) 
		canvas = GLMakieArea()
    
		connect_signal_realize!(canvas) do self
			screen = create_glmakie_screen(canvas)
			display(screen, fig)
			return nothing
		end

		canvas
	end

    """
    ```
    create_gl_makie_screen(::GLMakieArea; screen_config...) -> GLMakie.Screen{GLMakieArea}
    ```
    For a `GLMakieArea`, create a `GLMakie.Screen` that can be used to display makie graphics
    """
    function create_glmakie_screen(area::GLMakieArea; screen_config...)

        if !get_is_realized(area) 
            log_critical("MousetrapMakie", "In MousetrapMakie.create_glmakie_screen: GLMakieArea is not yet realized, it's internal OpenGL context cannot yet be accessed")
        end

        config = Makie.merge_screen_config(GLMakie.ScreenConfig, Dict{Symbol, Any}(screen_config))
        
        set_is_visible!(area, config.visible)
        set_expand!(area, true)

        # quote from https://github.com/JuliaGtk/Gtk4Makie.jl/blob/main/src/screen.jl#L342
        shader_cache = GLAbstraction.ShaderCache(area)
        ShaderAbstractions.switch_context!(area)
        fb = GLMakie.GLFramebuffer((1, 1)) # resized on GLMakieArea realization later

        postprocessors = [
            config.ssao ? ssao_postprocessor(fb, shader_cache) : empty_postprocessor(),
            OIT_postprocessor(fb, shader_cache),
            config.fxaa ? fxaa_postprocessor(fb, shader_cache) : empty_postprocessor(),
            to_screen_postprocessor(fb, shader_cache, area.framebuffer_id)
        ]

        screen = GLMakie.Screen(
            area, false, shader_cache, fb,
            config, false,
            nothing,
            Dict{WeakRef, GLMakie.ScreenID}(),
            GLMakie.ScreenArea[],
            Tuple{GLMakie.ZIndex, GLMakie.ScreenID, GLMakie.RenderObject}[],
            postprocessors,
            Dict{UInt64, GLMakie.RenderObject}(),
            Dict{UInt32, Makie.AbstractPlot}(),
            false,
        )
        # end quote

        screen.scalefactor[] = !isnothing(config.scalefactor) ? config.scalefactor : Mousetrap.get_scale_factor(area)
        screen.px_per_unit[] = !isnothing(config.px_per_unit) ? config.px_per_unit : screen.scalefactor[]
        area.screen = screen
        
        set_tick_callback!(area) do clock::FrameClock
            GLMakie.requires_update(area.screen) && queue_render(area.glarea)
            GLMakie.was_destroyed(area) ? TICK_CALLBACK_RESULT_DISCONTINUE : TICK_CALLBACK_RESULT_CONTINUE
        end
        return screen
    end
end