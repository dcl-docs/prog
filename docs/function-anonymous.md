
# Anonymous functions


```r
library(tidyverse)
```

Most functions you'll encounter are named. **Named functions** are functions that are assigned to a variable. The variable allows you to call the function wherever you'd like without repeating the original code.

`excited_word()` is a named function that turns a bored word into an excited one. The variable `excited_word` contains the function's code, while `excited_word()` calls the function.


```r
excited_word <- function(word) str_glue("{str_to_upper(word)}!!!")

excited_word
#> function(word) str_glue("{str_to_upper(word)}!!!")

excited_word("pinecones")
#> PINECONES!!!
```

**Anonymous functions** are functions without names. They're useful when you want to create a new function, but don't plan on calling that function again. For example, you'll commonly use anonymous function as arguments to other functions.

In base R, the syntax for creating an anonymous function is very similar to the syntax for a named function. The only difference is that you don't assign the function to a variable.

The following is the anonymous function version of `excited_word()`. It contains only the function's code.


```r
function(word) str_glue("{str_to_upper(word)}!!!")
#> function(word) str_glue("{str_to_upper(word)}!!!")
```

You can call anonymous functions, although you have to wrap the entire function in parentheses. 


```r
(function(word) str_glue("{str_to_upper(word)}!!!"))("pinecones")
#> PINECONES!!!
```

Fortunately, the tidyverse includes shortcuts for creating anonymous functions that make them much easier to read. You'll learn about these shortcuts in the sections on purrr.

