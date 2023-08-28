# Predicate functions


```r
library(tidyverse)
```

Predicate functions are functions that return a single `TRUE` or `FALSE`. You use predicate functions to check if your input meets some condition. For example, `is.character()` is a predicate function that returns `TRUE` if its input is of type character and `FALSE` otherwise.


```r
is.character("a")
#> [1] TRUE
```


```r
is.character(4.5)
#> [1] FALSE
```

R does not have scalars. `"a"` is actually a character vector of length 1. `is.character()` and similar functions return a single value for all vectors, whether they have 1 element or many.


```r
x <- c("a", "b")
is.character(x)
#> [1] TRUE
```

In atomic vectors like `x`, all the elements must be the same type. The type of the individual elements will always be the same as the type of the atomic vector. You can use the function `typeof()` to find the type of a vector (or any other object in R).


```r
typeof(x)
#> [1] "character"
```

`is.character()` simply checks whether `x` is of type character.

If the vector is not a character vector, `is.character()` will return `FALSE`.


```r
y <- c(1, 3)
typeof(y)
#> [1] "double"
is.character(y)
#> [1] FALSE
```

Lists can have elements of any type. Even if all the elements of a list are of type character, the list is not a character vector, and `is.character()` will return `FALSE`.


```r
z <- list("a", "b")
typeof(z)
#> [1] "list"
is.character(z)
#> [1] FALSE
```
