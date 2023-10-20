# MousetrapMakie.jl

Experimental package that adds `GLMakieArea`, a [Mousetrap](https://github.com/Clemapfel/Mousetrap.jl/) widget that allows displaying [GLMakie](https://github.com/MakieOrg/Makie.jl) plots, similar to how [Gtk4Makie.jl](https://github.com/JuliaGtk/Gtk4Makie.jl) allows the same for GTK4.jl.

This package is not production ready and should be considered in early alpha. The following features are still missing:

+ Applying a post-processing config is not yet implemented
+ Modifying the screen after it is realized remains untested
+ Setups with multiple `GLMakie.Screen`s remain untested
+ `runtests.jl` is unimplemented, meaning CI through GitHub actions is not yet set up
+ The Makie event model is ignored completely, only Mousetraps event controllers allow for user input

If you are experienced with Makie, consider opening a PR to fully implement this package and extend its functionalities. Any significant contributor will be credited as an author. See [`src/MousetrapMakie.jl`](./src/MousetrapMakie.jl), which is heavily commented to make understanding and extending the package easier.

See the [Mousetrap.jl manual chapter on OpenGL integration](https://clemens-cords.com/mousetrap/01_manual/12_opengl_integration/) for more information.

# Installation

```julia
import Pkg
begin
    Pkg.add(url="https://github.com/clemapfel/mousetrap_jll")
    Pkg.add(url="https://github.com/clemapfel/Mousetrap.jl")
    Pkg.add(url="https://github.com/clemapfel/MousetrapMakie.jl")
end
```

# Showcase

```julia
using Mousetrap, MousetrapMakie, GLMakie
main() do app::Application
    window = Window(app)
    canvas = GLMakieArea()
    set_child!(window, canvas)

    screen = Ref{Union{Nothing, GLMakie.Screen{GLMakieArea}}}(nothing)
    connect_signal_realize!(canvas) do self
        screen[] = create_glmakie_screen(canvas)
        display(screen[], scatter(rand(123)))
        return nothing
    end
    present!(window)
end
```

![](https://github.com/Clemapfel/Mousetrap.jl/blob/main/docs/src/assets/makie_scatter.png)

## Credits & Contribution

`MousetrapMakie` was created by `Mousetrap.jl`s main developer, [C. Cords](https://clemens-cords.com).

## License

Licensed [lGPL-3.0](https://www.gnu.org/licenses/lgpl-3.0.de.html), meaning it available for both open-source, as well as closed-source, commercial use.
