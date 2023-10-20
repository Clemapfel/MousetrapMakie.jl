using Test # dummy tests, actual testing is not yet implemented 

using Mousetrap, MousetrapMakie, GLMakie
main() do app::Application
    window = Window(app)
    canvas = GLMakieArea()
    set_child!(window, canvas)

    screen = Ref{Union{Nothing, GLMakie.Screen{GLMakieArea}}}(nothing)
    connect_signal_realize!(canvas) do self
        screen[] = create_glmakie_screen(canvas)
        display(screen[], scatter(rand(123)))
        @test screen[] isa GLMakie.Screen
        quit!(app)
        return nothing
    end
    present!(window)
end