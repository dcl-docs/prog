

# Summary



Tidy evaluation is a complex subject, but you don't really need to understand how it works to start using it in your functions. The following is a brief, practical summary of the most common use cases. 

## Passing full expressions with `...`

You can use `...` to pass full expressions into a function. For example, the following function applies `filter()` to `mpg.`


```r
mpg_filter <- function(...) {
  mpg %>% 
    filter(...)
}

mpg_filter(manufacturer == "audi", year == 1999)
#> # A tibble: 9 x 11
#>   manufacturer model  displ  year   cyl trans drv     cty   hwy fl    class
#>   <chr>        <chr>  <dbl> <int> <int> <chr> <chr> <int> <int> <chr> <chr>
#> 1 audi         a4       1.8  1999     4 auto… f        18    29 p     comp…
#> 2 audi         a4       1.8  1999     4 manu… f        21    29 p     comp…
#> 3 audi         a4       2.8  1999     6 auto… f        16    26 p     comp…
#> 4 audi         a4       2.8  1999     6 manu… f        18    26 p     comp…
#> 5 audi         a4 qu…   1.8  1999     4 manu… 4        18    26 p     comp…
#> 6 audi         a4 qu…   1.8  1999     4 auto… 4        16    25 p     comp…
#> # … with 3 more rows
```

`...` can take any number of arguments, so we can filter by an unlimited number of conditions.


```r
mpg_filter(
  manufacturer == "audi", 
  year == 1999, 
  drv == "f", 
  fl == "p"
)
#> # A tibble: 4 x 11
#>   manufacturer model displ  year   cyl trans  drv     cty   hwy fl    class
#>   <chr>        <chr> <dbl> <int> <int> <chr>  <chr> <int> <int> <chr> <chr>
#> 1 audi         a4      1.8  1999     4 auto(… f        18    29 p     comp…
#> 2 audi         a4      1.8  1999     4 manua… f        21    29 p     comp…
#> 3 audi         a4      2.8  1999     6 auto(… f        16    26 p     comp…
#> 4 audi         a4      2.8  1999     6 manua… f        18    26 p     comp…
```

Passing `...` works anytime all you want to do is pass a full expression into a dplyr function. Here's another example that uses `select()`.


```r
mpg_select <- function(...) {
  mpg %>% 
    select(...)
}

mpg_select(car = model, drivetrain = drv)
#> # A tibble: 234 x 2
#>   car   drivetrain
#>   <chr> <chr>     
#> 1 a4    f         
#> 2 a4    f         
#> 3 a4    f         
#> 4 a4    f         
#> 5 a4    f         
#> 6 a4    f         
#> # … with 228 more rows
```

## Named arguments

Sometimes, `...` won't work because you'll want to supply your function with named arguments.

In the introduction, we noted the following function that doesn't work:


```r
grouped_mean <- function(df, group_var, summary_var) {
  df %>% 
    group_by(group_var) %>% 
    summarize(mean = mean(summary_var))
}

grouped_mean(df = mpg, group_var = manufacturer, summary_var = cty)
#> Error: Column `group_var` is unknown
```

We can create a function that works by by using `enquo()` and `!!`. 


```r
grouped_mean <- function(df, group_var, summary_var) {
  group_var <- enquo(group_var)
  summary_var <- enquo(summary_var)
  
  df %>% 
    group_by(!! group_var) %>% 
    summarize(mean = mean(!! summary_var))
}

grouped_mean(df = mpg, group_var = manufacturer, summary_var = cty)
#> # A tibble: 15 x 2
#>   manufacturer  mean
#>   <chr>        <dbl>
#> 1 audi          17.6
#> 2 chevrolet     15  
#> 3 dodge         13.1
#> 4 ford          14  
#> 5 honda         24.4
#> 6 hyundai       18.6
#> # … with 9 more rows
```

Here's the steps:

* Apply `enquo()` to the arguments that refer to column names.
* When you want to reference those arguments, put `!!` before their names.

## Named arguments and any number of additional arguments

Sometimes, you'll want your function to take named arguments, but you'll also want to allow for any number of additional arguments. You can use `enquo()`, `!!`, and `...`.


```r
grouped_mean_2 <- function(df, summary_var, ...) {
  summary_var <- enquo(summary_var)
  
  df %>% 
    group_by(...) %>% 
    summarize(mean = mean(!! summary_var))
}

grouped_mean_2(df = mpg, summary_var = cty, year, drv)
#> # A tibble: 6 x 3
#> # Groups:   year [2]
#>    year drv    mean
#>   <int> <chr> <dbl>
#> 1  1999 4      14.2
#> 2  1999 f      20.0
#> 3  1999 r      14  
#> 4  2008 4      14.4
#> 5  2008 f      20.0
#> 6  2008 r      14.1
```

With the `...`, we can pass any number of grouping variables into `group_by()`.


```r
grouped_mean_2(df = mpg, summary_var = cty, year, drv, class)
#> # A tibble: 23 x 4
#> # Groups:   year, drv [6]
#>    year drv   class       mean
#>   <int> <chr> <chr>      <dbl>
#> 1  1999 4     compact     16.5
#> 2  1999 4     midsize     15  
#> 3  1999 4     pickup      13  
#> 4  1999 4     subcompact  19.5
#> 5  1999 4     suv         13.8
#> 6  1999 f     compact     20.4
#> # … with 17 more rows
```

## Assigning names

Many of the dpylr verbs allow you to name or rename columns. When you want to pass the name of a column into your function, you need to:

* Apply `enquo()` to the argument giving the name
* Put `!!` before the name when you reference it
* Use `:=` instead of `=` to assign the name


```r
summary_mean <- function(df, summary_var, summary_name) {
  summary_var <- enquo(summary_var)
  summary_name <- enquo(summary_name)
  
  df %>% 
    summarize(!! summary_name := mean(!! summary_var))
}

summary_mean(df = mpg, summary_var = cty, summary_name = cty_mean)
#> # A tibble: 1 x 1
#>   cty_mean
#>      <dbl>
#> 1     16.9
```

## Recoding

`recode()` is also a dplyr verb. It is often useful to put your recode vector in the parameters section, instead of directly inside `recode()`. Use `!!!` to get this to work.


```r
recode_drv <- c("f" = "front", "r" = "rear", "4" = "four")

mpg %>% 
  mutate(drv = recode(drv, !!! recode_drv))
#> # A tibble: 234 x 11
#>   manufacturer model displ  year   cyl trans  drv     cty   hwy fl    class
#>   <chr>        <chr> <dbl> <int> <int> <chr>  <chr> <int> <int> <chr> <chr>
#> 1 audi         a4      1.8  1999     4 auto(… front    18    29 p     comp…
#> 2 audi         a4      1.8  1999     4 manua… front    21    29 p     comp…
#> 3 audi         a4      2    2008     4 manua… front    20    31 p     comp…
#> 4 audi         a4      2    2008     4 auto(… front    21    30 p     comp…
#> 5 audi         a4      2.8  1999     6 auto(… front    16    26 p     comp…
#> 6 audi         a4      2.8  1999     6 manua… front    18    26 p     comp…
#> # … with 228 more rows
```

