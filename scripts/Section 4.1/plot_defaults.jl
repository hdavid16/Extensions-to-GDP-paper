include(srcdir("plots.jl"))

#colors and kwargs
c = palette(:seaborn_bright)
plot_kw_args = (
    xlabel=L"x_1", 
    ylabel=L"x_2",
    xlim=(0,10),
    ylim=(0,7),
    xticks=0:10,
    yticks=0:7,
    size=(700,300),
    guidefont=14,
    right_margin=3mm,
    left_margin=3mm,
    bottom_margin=3mm,
)