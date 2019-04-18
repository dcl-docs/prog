set.seed(2466)

options(
  digits = 3,
  dplyr.print_max = 6,
  dplyr.print_min = 6
)

knitr::opts_chunk$set(
  cache = TRUE,
  collapse = TRUE,
  comment = "#>",
  fig.align = 'center',
  fig.asp = 0.618,  # 1 / phi
  fig.show = "hold"
)

image_dpi <- 125

# Stamps plots with a tag 
# Idea from Claus Wilke's "Data Visualization" https://serialmentor.com/dataviz/
stamp <- function(
  tag = "Bad", tag_color = "#B33A3A", tag_size = 16, tag_padding = 1
)
{
  list(
    theme(
      plot.tag = element_text(color = tag_color, size = tag_size),
      plot.tag.position = "topright"
    ),
    labs(
      tag =
        str_pad(tag, width = str_length(tag) + tag_padding, side = "left")
    )
  )
}

