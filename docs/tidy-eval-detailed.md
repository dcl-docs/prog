
# Tidy evaluation


```r
library(tidyverse)
```

Now, we'll go into some more detail about tidy evaluation. We'll explain when and why you need tidy evaluation, and what's going on with `enquo()`, `!!`, and `!!!`.

You don't always need tidy evaluation when programming with dplyr. For example, the following function works just fine.


```r
filter_fun_1 <- function(df, value) {
  df %>% 
    filter(model == value) %>% 
    nrow()
}

filter_fun_1(df = mpg, value = "corvette")
#> [1] 5
```

But if we want to make this function more general by adding an argument to specify a column, we'll run into trouble.


```r
filter_fun_2 <- function(df, var, value) {
  df %>% 
    filter(var == value) %>% 
    nrow()
}

filter_fun_2(df = mpg, var = model, value = "corvette")
#> Error: object 'model' not found
```

You need tidy evaluation if you want to build a function that passes the names of tibble columns into dplyr verbs.

Here's another example of a function that doesn't work:


```r
grouped_mean <- function(df, group_var, summary_var) {
  df %>% 
    group_by(group_var) %>% 
    summarize(mean = mean(summary_var))
}

grouped_mean(df = mpg, group_var = manufacturer, summary_var = cty)
#> Error: Column `group_var` is unknown
```

In the following sections, we'll explore why `grouped_mean()` doesn't work and show you how to create a function that does.

## Quoting functions

### Quoted arguments

Before we can explain what's going wrong in functions like `grouped_mean()`, we need to lay some groundwork. In R, you can divide function arguments into two classes: __evaluated__ and __quoted__. 

Evaluated arguments are what you might think of as "normal." Here's an example of a function that evaluates its function arguments.


```r
log(2)
#> [1] 0.693
```

We can also save 2 as a variable and get the same answer.


```r
x <- 2

log(x)
#> [1] 0.693
```

Code in an evaluated argument executes the same regardless of whether or not it's in a function argument. So `x` evaluates to 2 whether it's outside `log()`


```r
x
#> [1] 2
```

or inside.


```r
log(x) == log(2)
#> [1] TRUE
```

Because `log()` evaluates its arguments, it figures out what `x` refers to before operating on `x`. In our example, `log()` figures out that `x` refers to 2, and then takes the log of 2. For a function like `log()`, evaluating its argument seems like an obviously good idea. It would be meaningless to take the log of the letter "x". Sometimes, however, functions don't want to evaluate their arguments. 
Let's find out if dplyr functions use evaluated arguments. Here's a dplyr function.


```r
mpg %>% 
  select(cty)
#> # A tibble: 234 x 1
#>     cty
#>   <int>
#> 1    18
#> 2    21
#> 3    20
#> 4    21
#> 5    16
#> 6    18
#> # … with 228 more rows
```

In this case, let's just consider the `cty` argument, even though `mpg` is technically an argument as well. 

If `select()` evaluates its argument, then `cty` should evaluate to the same thing inside `select()` as it does outside `select()`. Inside `select()`, we know that `cty` somehow refers to a column of `mpg`. Does it evaluate to a column of `mpg` outside `select()`?


```r
cty
#> Error in eval(expr, envir, enclos): object 'cty' not found
```

No. R doesn't know what `cty` refers to, because `cty`, unlike `x`, doesn't exist in the global environment. It only exists as an element of `mpg`. 

To make this point even more explicit, let's assign a number to `cty`.


```r
cty <- 3

cty
#> [1] 3
```

Now, `cty` evaluates to `3` outside `select()`, but `select(cty)` still works as expected.


```r
mpg %>% 
  select(cty)
#> # A tibble: 234 x 1
#>     cty
#>   <int>
#> 1    18
#> 2    21
#> 3    20
#> 4    21
#> 5    16
#> 6    18
#> # … with 228 more rows
```

Arguments like `cty` are __quoted__. Instead of immediately evaluating `cty` before operating, `select()` and the other dplyr verbs hold on to what was literally supplied as an argument. Here, that's just "cty", but other cases can be more complicated. Quoting allows `select()` and the other dplyr verbs to use their input as they want without worrying about how that input evaluates in the global environment. In our example, quoting its argument allows `select()` to look for `cty` inside the `mpg` tibble, without worrying about `cty` referring to `3` in the global environment.

Note that dplyr verbs only quote the arguments that supply column names. They do not quote the argument that refers to the data you pipe in, or non-column-name arguments like `count()`'s `sort` argument or `top_n()`'s `n` argument.

dplyr's quoting behavior makes it really easy to use. You can supply bare names of columns to dplyr functions and they just work. However, the quoting behavior causes some wrinkles when you want to program with dplyr. 

You might now have a hypothesis about why `grouped_mean()` didn't work. Here it is again.


```r
grouped_mean <- function(df, group_var, summary_var) {
  df %>% 
    group_by(group_var) %>% 
    summarize(mean = mean(summary_var))
}

grouped_mean(df = mpg, group_var = manufacturer, summary_var = cty)
#> Error: Column `group_var` is unknown
```

The error says that the column `group_var` is unknown. Because `group_by()` quotes its argument, it didn't evaluate `group_var`, find out that it refers to `manufacturer`, and then look for a column named `manufacturer`. Instead, it took its input literally and looked for a column named `group_var`. `mpg` doesn't have a column called `group_var`, so we got an error.

We want `group_by()` to understand that `group_var` refers to `manufacturer`, so we need to change our function. Before diving into these changes, here's a summary of the points covered so far:

* Some functions evaluate their arguments and some function quote their arguments.
* If a function quotes its argument, the argument will evaluate differently inside and outside the function.
* dplyr functions quote the arguments that take tibble column names.

### Strings and `glue()`

If we want `group_by()` to understand that `group_var` refers to `manufacturer`, we're going to have to _unquote_ `group_var`. 

Before we talk about how to do this with dplyr, let's take a moment to examine a situation in which you've actually already been quoting and unquoting input. 

When you create a string, R doesn't evaluate its contents. When you type something like:


```r
"y <- 1"
#> [1] "y <- 1"
```

R creates a string, not an object named `y` with a value of 1. 

Sometimes, though, you'll want to write a function that inserts a variable into a string. For example, say we want to write a function that tells you what species of animal you are. 

You can probably predict that the following function won't work.


```r
species <- function(my_species) {
  "I am a my_species"
}

species("human")
#> [1] "I am a my_species"
```

We need to tell our function that we actually do want to evaluate `my_species`. As you've already learned, you can do this with `str_glue` and `{}`.


```r
species <- function(my_species) {
  str_glue("I am a {my_species}")
}

species("human")
#> I am a human
```

The `{}` tells `str_glue()` to evaluate `my_species` before constructing the string. Unfortunately, we can't just use `{}` to get dplyr verbs to evaluate the arguments we want. We'll need to figure out an equivalent to `{}` for dplyr function calls.

### Quosures 

One reason we can't just generalize from our string example and use `{}` is that when dplyr functions quote their arguments, they don't quote and create strings. When you quote with quotation marks, as you know, you create a string.


```r
"y <- 1"
#> [1] "y <- 1"
```

But when dplyr functions quote their arguments, they create something called a _quosure_.

You can create your own quosure with the function `quo()`. 


```r
quo(y <- 1)
#> <quosure>
#> expr: ^y <- 1
#> env:  global
```

Our quosure has two parts: the `expr` (which stands for _expression_) and the `env` (which stands for _environment_). 

You can think of expressions like recipes. A recipe for chocolate chip cookies specifies how to make the cookies, but does not itself create any cookies. Similarly, the expression `y <- 1` species how to create a variable, but doesn't actually create that variable. Just as you need to carry out the recipe to create cookies, R needs to evaluate the expression to produce the results.

Recipes, unfortunately, aren't sufficient for cookies. You also need a stock of ingredients, like flour and chocolate chips. Similarly, in order to evaluate an expression, R needs an environment that supplies variables. Different types of flour and chocolate chips can create different cookies, and different environments can cause the same expression to be evaluated differently.

If we place `quo(y <- 1)` inside a function, the environment will change.


```r
quo_fun <- function() {
  quo(y <- 1)
}

quo_fun()
#> <quosure>
#> expr: ^y <- 1
#> env:  0x7f8f88edac08
```

Quosures are objects and so can be passed around, carrying their environment with them.


```r
more_quo_fun <- function(my_quosure) {
  my_quosure
}

more_quo_fun(quo(y <- 1))
#> <quosure>
#> expr: ^y <- 1
#> env:  global
```

Now you know that:

* dplyr quotes its arguments and creates quosures, which consist of an expression and an environment. An expression is kind of like a recipe, and the environment is what supplies the ingredients you use to carry out that recipe.
* You can create a quosure with `quo()`.

## Wrapping quoting functions

### `enquo()` and `!!`

Now that we've gone over some theory, we can return to the task of fixing `grouped_mean()`.

You just learned that dplyr verbs create quosures. In order to make our function work, we'll need to make our own quosure that captures our desired meaning of `group_var` and `summary_var`. Here's our earlier, unsuccessful function.


```r
grouped_mean <- function(df, group_var, summarize_var) {
  df %>% 
    group_by(group_var) %>% 
    summarize(mean = mean(summarize_var))
}

grouped_mean(df = mpg, group_var = manufacturer, summarize_var = cty)
#> Error: Column `group_var` is unknown
```

We want to track the environment of `group_var` so that `group_by()` knows that it refers to `manufacturer`. We can do this with `quo()`.


```r
grouped_mean <- function(df, group_var, summarize_var) {
  print(group_var)
  
  df %>% 
    group_by(group_var) %>% 
    summarize(mean = mean(summarize_var))
}

grouped_mean(
  df = mpg, 
  group_var = quo(manufacturer), 
  summarize_var = quo(cty)
)
#> <quosure>
#> expr: ^manufacturer
#> env:  global
#> Error: Column `group_var` is unknown
```

Our `print()` statement lets us know what `group_var` looks like inside the function. `group_var` is a quosure and evaluates to `manufacturer,` which seems like a step in the right direction. 

However, our function still isn't giving us what we want. `group_by()` still quotes `group_var` and looks for a column called `group_var`. We've already quoted the input with `quo()`, but `group_by()` doesn't know that and so is just carrying on as usual.

We can tell `group_by()` not to quote by using `!!` (pronounced "bang bang"). `!!` says something like "evaluate me!" or "unquote!"


```r
grouped_mean <- function(df, group_var, summarize_var) {
  print(group_var)
  
  df %>% 
    group_by(!! group_var) %>% 
    summarize(mean = mean(!! summarize_var))
}

grouped_mean(
  df = mpg, 
  group_var = quo(manufacturer), 
  summarize_var = quo(cty)
)
#> <quosure>
#> expr: ^manufacturer
#> env:  global
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

Success!!

`quo()` and `!!` work well, but it's kind of a hassle to have to `quo()` our input each time. It would be even better if we could write the function call like this:


```r
grouped_mean(df = mpg, group_var = manufacturer, summarize_var = cty)
```

To do so, we'll take care of the quoting _inside_ our function. We can't use `quo()` to quote inside our function.


```r
grouped_mean <- function(df, group_var, summary_var) {
  group_var <- quo(group_var)
  summary_var <- quo(summary_var)
  print(group_var)
  
  df %>% 
    group_by(!! group_var) %>% 
    summarize(mean = mean(!! summary_var))
}

grouped_mean(df = mpg, group_var = manufacturer, summary_var = cty)
#> <quosure>
#> expr: ^group_var
#> env:  0x7f8f88e064c0
#> Error: Column `group_var` is unknown
```

The environment of our quosure is wrong. We want R to evaluate `group_var` using the global environment, not the environment of our function. We'll need `quo()`'s cousin, `enquo()`, in order to capture the correct environment of `group_var`. 


```r
enquo_fun <- function(group_var) {
  print(enquo(group_var))
}

enquo_fun(group_var = manufacturer)
#> <quosure>
#> expr: ^manufacturer
#> env:  global
```

Now, we can rewrite `grouped_mean()`.


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

You can use this same technique for any of the dplyr verbs.


```r
filter_var <- function(var, value) {
  var <- enquo(var)
  
  mpg %>% 
    filter(!! var == value)
}

filter_var(class, "minivan")
#> # A tibble: 11 x 11
#>   manufacturer model  displ  year   cyl trans drv     cty   hwy fl    class
#>   <chr>        <chr>  <dbl> <int> <int> <chr> <chr> <int> <int> <chr> <chr>
#> 1 dodge        carav…   2.4  1999     4 auto… f        18    24 r     mini…
#> 2 dodge        carav…   3    1999     6 auto… f        17    24 r     mini…
#> 3 dodge        carav…   3.3  1999     6 auto… f        16    22 r     mini…
#> 4 dodge        carav…   3.3  1999     6 auto… f        16    22 r     mini…
#> 5 dodge        carav…   3.3  2008     6 auto… f        17    24 r     mini…
#> 6 dodge        carav…   3.3  2008     6 auto… f        17    24 r     mini…
#> # … with 5 more rows
```

The `enquo()` and `!!` strategy is incredibly useful, and you don't need to fully understand the theory behind it in order to write successful functions. If some of the earlier explanation is still confusing, don't worry about it too much. Tidy evaluation is a complicated subject, and it takes a while to really grasp what's going on behind `enquo()` and `!!`.

In summary, to build a function that takes an argument to a dplyr verb, use the following template:


```r
my_tidyeval_function <- function(column_name) {
  column_name <- enquo(column_name)
  
  df %>% 
    dplyr_verb(!! column_name)
}
```

### Passing `...`

Say you want to extend `grouped_mean()` so that you can group by any number of variables. You might have noticed that some functions, like scoped verbs and the purrr functions, take `...` as a final argument, allowing you to specify additional arguments. We can use that same functionality here.


```r
grouped_mean_2 <- function(df, summary_var, ...) {
  summary_var <- enquo(summary_var)
  
  df %>% 
    group_by(...) %>% 
    summarize(mean = mean(!! summary_var))
}

grouped_mean_2(df = mpg, summary_var = cty, manufacturer, model)
#> # A tibble: 38 x 3
#> # Groups:   manufacturer [15]
#>   manufacturer model               mean
#>   <chr>        <chr>              <dbl>
#> 1 audi         a4                  18.9
#> 2 audi         a4 quattro          17.1
#> 3 audi         a6 quattro          16  
#> 4 chevrolet    c1500 suburban 2wd  12.8
#> 5 chevrolet    corvette            15.4
#> 6 chevrolet    k1500 tahoe 4wd     12.5
#> # … with 32 more rows
```

Notice that with ..., we didn’t have to use `enquo()` or `!!`. `...` takes care of all the quoting and unquoting for you.

You can also use `...` to pass in full expressions to dplyr verbs.


```r
filter_fun <- function(df, summary_var, ...) {
  summarize_var <- enquo(summary_var)
  
  df %>% 
    filter(...) 
}

filter_fun(mpg, manufacturer == "audi", model == "a4")
#> # A tibble: 7 x 11
#>   manufacturer model displ  year   cyl trans  drv     cty   hwy fl    class
#>   <chr>        <chr> <dbl> <int> <int> <chr>  <chr> <int> <int> <chr> <chr>
#> 1 audi         a4      1.8  1999     4 auto(… f        18    29 p     comp…
#> 2 audi         a4      1.8  1999     4 manua… f        21    29 p     comp…
#> 3 audi         a4      2    2008     4 manua… f        20    31 p     comp…
#> 4 audi         a4      2    2008     4 auto(… f        21    30 p     comp…
#> 5 audi         a4      2.8  1999     6 auto(… f        16    26 p     comp…
#> 6 audi         a4      2.8  1999     6 manua… f        18    26 p     comp…
#> # … with 1 more row
```

### Assigning names

Let's return to our `grouped_mean()` function. We finally got it working in the last section. Here it is again:


```r
grouped_mean <- function(df, group_var, summarize_var) {
  group_var <- enquo(group_var)
  summarize_var <- enquo(summarize_var)
  
  df %>% 
    group_by(!! group_var) %>% 
    summarize(mean = mean(!! summarize_var))
}
```

It would be nice if we could name the `mean` column something more informative.

Maybe we can just apply our `enquo()` and `!!` strategy?


```r
grouped_mean <- function(df, group_var, summary_var, summary_name) {
  group_var <- enquo(group_var)
  summary_var <- enquo(summary_var)
  summary_name <- enquo(summary_name)
  
  df %>% 
    group_by(!! group_var) %>% 
    summarize(!! summary_name = mean(!! summary_var))
}

grouped_mean(
  df = mpg, 
  group_var = manufacturer, 
  summary_var = hwy, 
  summary_name = mean_hwy
)
```

This doesn't work. It turns out that you can't use `!!` on both sides of an `=`. We have to use a special `=` that looks like `:=`.


```r
grouped_mean <- function(df, group_var, summary_var, summary_name) {
  group_var <- enquo(group_var)
  summary_var <- enquo(summary_var)
  summary_name <- enquo(summary_name)
  
  df %>% 
    group_by(!! group_var) %>% 
    summarize(!! summary_name := mean(!! summary_var))
}

grouped_mean(
  df = mpg, 
  group_var = manufacturer, 
  summary_var = hwy, 
  summary_name = mean_hwy
)
#> # A tibble: 15 x 2
#>   manufacturer mean_hwy
#>   <chr>           <dbl>
#> 1 audi             26.4
#> 2 chevrolet        21.9
#> 3 dodge            17.9
#> 4 ford             19.4
#> 5 honda            32.6
#> 6 hyundai          26.9
#> # … with 9 more rows
```

Success!!

## Passing vectors with `!!!`

Here's one more common tidy evaluation use case. 

Say you want to use `recode()` to recode a variable. 


```r
mpg %>% 
  mutate(drv = recode(drv, "f" = "front", "r" = "rear", "4" = "four")) %>% 
  select(drv)
#> # A tibble: 234 x 1
#>   drv  
#>   <chr>
#> 1 front
#> 2 front
#> 3 front
#> 4 front
#> 5 front
#> 6 front
#> # … with 228 more rows
```

It's often a good idea to store your recode mapping in a parameter because you might want to change the mapping later on or use it in other locations. 

We can store the mapping in a named character vector.


```r
drv_recode <- c("f" = "front", "r" = "rear", "4" = "four")
```

However, now `recode()` doesn't work.


```r
mpg %>% 
  mutate(drv = recode(drv, drv_recode)) %>% 
  select(drv)
#> Argument 2 must be named, not unnamed
```

`recode()`, like `group_by()`, `summarize()`, and the other dplyr functions, quotes its input. We therefore need to tell `recode()` to evaluate `recode_key` immediately. Let's try `!!`.


```r
mpg %>% 
  mutate(drv = recode(drv, !! drv_recode)) %>% 
  select(drv)
#> Argument 2 must be named, not unnamed
```

`!!` doesn't work because `recode_key` is a vector. Not only do we need to immediately evaluate `recode_key`, we also need to unpack its contents. To do so, we'll use `!!!`.


```r
mpg %>% 
  mutate(drv = recode(drv, !!! drv_recode)) %>% 
  select(drv)
#> # A tibble: 234 x 1
#>   drv  
#>   <chr>
#> 1 front
#> 2 front
#> 3 front
#> 4 front
#> 5 front
#> 6 front
#> # … with 228 more rows
```

Success!!!
