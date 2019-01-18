# Strap: The Ultimate Dotfiles Framework

> **_NOTE:_**  Strap is currently being ported from a previous version.  It currently works, but it doesn't install very much.  Yet.

`strap` is a dotfiles framework that is designed to do one thing extremely well: 

Strap will take your machine from a zero state (e.g. right after you buy it or receive it from your 
employer) and install and configure everything you want on your machine in a *single command*, in *one shot*.  Run 
strap and you can rest assured that your machine will have your favorite command line tools, system defaults, gui 
applications, and development tools installed and ready to go.

Strap was initially created to help newly-hired software engineers get up and running and
productive in *minutes* after they receive their machine instead of the hours or days it usually takes.  But Strap
isn't limited to software engineering needs - anyone can use Strap to install what they want - graphics software, 
video editing, web browsers, whatever.

## Watch It Run!

Here's a little `strap run` recording to whet your appetite for the things Strap can do for you:

[![asciicast](https://asciinema.org/a/188040.png)](https://asciinema.org/a/188040)


## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/ultimatedotfiles/strap/master/install | bash
```

Then set the following in ~/.bash_profile, ~/.bashrc or ~/.zshrc (or whatever you prefer):

```bash
export PATH="$HOME/.strap/releases/current/bin:$PATH"
```

## Overview

How does strap work?

### It's Just Bash, Man

Strap is a command line tool with a set of sub-commands and packages written in 100% Bash scripts to ensure it can run
out of the box on pretty much any Mac or Linux machine created in the last few years.  It doesn't require Ruby, 
Python, Java or any other tool to be installed on your box first in order to run (but you can install those 
with Strap as you see fit). Strap should work on any machine with Bash 3.2.57 or later.

That said, don't worry if you prefer zsh or any other shell.  Bash is just used to write and run strap - you 
can install and use zsh or any other shell you prefer.

### Built on the Shoulders of Giants

Don't worry, we're not re-inventing the wheel.
 
Strap is mostly a set of really convenient wrapper functions
and commands built on top of homebrew.  Strap fills a really important gap: while homebrew is primarily concerned with 
managing packages on your machine, Strap leverages that and also enables user and machine-specific configuration for 
those packages.

For example, you might have installed a homebrew package and then in its output, that package says something like:

> After this is installed, modify your ~/.bash_profile or ~/.zshrc to include the following init line...

Well, that's nice, but shouldn't that part be automated too?  Also what about operating system default configuration?
That's not a software package, it's configuration, and homebrew mostly doesn't address those concerns.  But Strap does.

Strap is homebrew + automating 'the last mile' to get you to an ideally-configured machine without
having to work. It is basically: "I want to use one command and that's it.  If you need something from me, 
prompt me, but don't make me do any work at all beyond that."  Now that's what we're talking about!

### Declarative Configuration

Even though Strap is built with bash, you don't have to know bash at all to use it.  Once installed, Strap looks 
at an easy-to-understand `strap.yml` configuration file that lists every thing you want installed or modified
on your system.

It reads this list and *converges* your machine to have the same state represented in the `strap.yml` file:  If 
something in the strap.yml file already exists on your machine, strap just skips it.  If something in the file doesn't
exist yet, strap will install it for you.  It can automatically upgrade things for you too.

This means Strap is *idempotent* - you can run it over and over again, and your machine will be in your desired state
every time you run it. Nice! 

Based on this, you can (and should) run strap regularly to ensure your system is configured how you want it and your 
software is up-to-date at all times.

### Pack It Up, Pack It In

Strap was purposefully designed to have a very lean core and delegate most functionality to packages.  Why 
is this important?

*Because you can extend Strap for your needs*.

That's right - if Strap doesn't have something you need, you can write a simple bash package to provide it.  Strap
gives you the ability to package up your bash functions, version them, and supply them to other Strap packages.  This
means Strap supports import-like behavior: a package can depend on other packages and *import* those
packages' library functions and variables.

Additionally, a Strap package can contain scripts that hook in to Strap's run lifecycle, kind of like a 'plugin'. This 
allows you to extend and enhance functionality that may not be in Strap by default.

And this helps prevent lock-in.  It allows you to get what you need on your timeline without waiting on anyone.  And it 
allows for a community to grow and provide open-source packages we can all benefit from.  And packages are 
just folders, so they can be created as simply as creating a new git repository.  And because 
GitHub is pretty much the de-facto git origin for open-source software these days, Strap has native git and GitHub 
integration too.

### Customization and Privacy

Because Strap is pluggable, you can 'point' it to any strap-compatible git repository.  This means that you can
have your own git repo that represents the customizations you care about.  And you can share this with the world so 
others can have awesome machine setups just like you.

But sometimes you (or companies) don't want the world to see what is installed on a machine for privacy or 
security reasons.  If this is a concern for you, you can host your Strap configuration and packages in a private git 
repository. Because of Strap's native GitHub integration, it can securely authenticate with GitHub and utilize your 
private git repositories (assuming your GitHub user account has access to said repositories).

You can even mix and match repositories: use Strap's defaults, then add in your company's private repository, then 
finally add in your personal repository to fill in any remaining missing gaps.  Any number of sources can be used 
during a strap run for machine convergence.

## Usage

Strap is a command line tool.  Assuming the strap installation's `bin` directory is in your `$PATH` as shown in the
installation instructions above, you can just type `strap` and see what happens:

```bash
me@myhost:~$ strap
strap version 0.0.1
usage: strap [options...] <command> [command_options...]
 
commands:
   help        Display help for a command
   run         Runs strap to ensure your machine is fully configured
   version     Display the version of strap
 
See `strap help <command>' for information on a specific command.
For full documentation, see: https://github.com/ultimatedotfiles/strap
```

The `strap` command itself is quite simple - it basically loads some common environment settings and that's pretty 
much it. From there, it delegates most functionality to sub-commands, very similar to how the `git` command-line tool 
works.  The sub-commands available to you are the combined set of Strap's built-in sub-commands and any sub-commands 
made available by any Strap packages you reference.

## Strap Packages

Strap is designed to have a lean core with most functionality coming from packages.  This section explains 
what packages are, how to use them, and how to write your own package(s) if you want to add or extend Strap 
functionality.

### What Is A Strap Package?

A Strap package is just a folder with bash scripts described by a `package.yml` file. 
This means Strap can access functionality from anywhere it can access a folder.  And because git repositories are 
folders, Strap can pull in functionality from anywhere it can access a git repository via a simple `git clone` command 
based on the package's unique identifier.

### Strap Package Identifier

A Strap Package Identifier is a string that uniquely identifies a Strap package.

The package identifier string format MUST adhere to the following definition:

    strap-package-id = group-id ":" package-name [":" package-version]
    
    group-id = "com.github." github-account-name
    
where
 * `github-account-name` equals a valid github username or organization name, for example `jsmith` or `ultimatedotfiles`
 * `package-name` equals a git repository name within the specified github account, for example `cool-package`
 * `package-version`, if present, equals a git [refname](https://git-scm.com/docs/gitrevisions#gitrevisions-emltrefnamegtemegemmasterememheadsmasterememrefsheadsmasterem) that MUST be a tag, branch
    or commit sha that can be provided as an argument to `git checkout`.
    
A package release SHOULD always have a `package-version` string that conforms to the semantic version name scheme 
defined in the [Semantic Versioning 2.0.0 specification](https://semver.org/spec/v2.0.0.html).

Some examples:

 * `com.github.acme:hello:0.2.1`
 * `com.github.ultimatedotfiles:cool-package:1.0.3`

> NOTE: we realize it is a rather constrictive requirement to have all packages hosted on github and conform to the
  specified location and naming scheme.  These restrictions will be relaxed when Strap's functionality
  is enhanced to support arbitrary repository locations (e.g. bitbucket, gitlab, Artifactory, etc).

#### Strap Package Resolution

How does Strap download a package based on the package identifier?

Consider the following Strap Package Identifier example:

    com.github.acme:hello:1.0.2
    
This tells strap to download the package source code obtained by (effectively) running:

```bash
git clone https://github.com/acme/hello
cd hello
git checkout tags/1.0.2
```

#### Strap Package Resolution Without `:package-version`
      
If there is not a `:package-version` suffix in a `strap-package-id`, a `:package-version` value of `:HEAD` will be 
assumed and the git repository's `origin/HEAD` will be used as the package source.

For example, consider the following Strap package id:

    com.github.acme:hello
    
This indicates the package source code will be obtained by (effectively) running:

```bash
git clone https://github.com/acme/hello

```
 
and no specific branch will be checked out (implying the default branch will be used, which is `master` in most cases).

> **WARNING**:
> 
> It is *strongly recommended to always specify a `:package-version` suffix* in every strap package idenfier to ensure
> deterministic (repeatable) behavior.  Omitting `:package-version` suffixes - and relying on the `:HEAD` default - 
> can cause errors or problems during a `strap` run. Omission can be useful while developing a package, but it is 
> recommended to provide a `:package-version` suffix at all other times.

### Strap Packages Directory

Any package referenced by you (or by other packages) that are not included in the Strap installation 
are automatically downloaded and stored in your `$HOME/.strap/packages` directory.

This directory is organized according to the following rules based on the Strap Package ID.  An example Strap
Package ID of `com.github.acme:hello:1.0.2` will be used for illustration purposes.

* The strap package id's `group-id` component is parsed, and period characters ( `.` ) are replaced with 
  forward-slash characters ( `/` ).  For example, the `group-id` of `com.github.acme` becomes `com/github/acme`

* The resulting string is appended with a forward-slash ( `/` ).  For example, `com/github/acme` becomes 
  `com/github/acme/`
  
* The resulting string is appended with the package id's `package-name` component.  For 
  example, `com/github/acme/` becomes `com/github/acme/hello`
  
* The resulting string is appended with a forward-slash ( `/` ).  For example, `com/github/acme/hello` becomes 
  `com/github/acme/hello/`

* The resulting string is appended with the `strap-package-id`'s `package-version` component if one exists, or `HEAD`
  if one doesn't exist.  For example:
  
  * A strap package id of `com.github.acme:hello:1.0.2` becomes `com/github/acme/hello/1.0.2` and
  * A strap package id of `com.github.acme:hello` becomes `com/github/acme/hello/HEAD`
  
* The resulting string is appended to the string `$HOME/.strap/packages/`.  For example,
  `com/github/acme/hello/1.0.2` becomes `$HOME/.strap/packages/com/github/acme/hello/1.0.2`

* The resulting string is used as the argument to the `mkdir -p` command, which is used to create the directory where 
  that package's code will be downloaded, for example:
  
  `mkdir -p "$HOME/.strap/packages/com/github/acme/hello/1.0.2"`


### Strap Package Structure

A strap package is a folder containing:

* A `META/package.yml` file
* Any number of bash scripts

Assuming `https://github.com/acme/hello` was a strap package repository, here is an example of what its directory 
structure might look like:

```
cmd/
    hello
hooks/
    run
lib/
    hello.sh
META/
    package.yml
```

The above tree shows the following:

* `META/package.yml` is a Strap package yaml file.  This file contains metadata about your package that Strap uses
  to ensure your package can be referenced by other packages, as well as enable any Strap sub-commands your package
  might provide, and more.

* `cmd/hello` is an executable script that can be executed as a strap sub-command.  That is, a strap user could
  type `strap hello` and strap would delegate execution to your `cmd/hello` script.  When committing this file to 
  source control, ensure that the file's executable flag is set, for example `chmod u+x cmd/hello`.

* `hooks/run` is an executable script that will execute when `strap run` is called. For example, if a strap user types
  `strap run` to kick off a run, strap will in turn invoke `hooks/run` as part of that execution phase.  Scripts in 
  the `hooks` directory must match exactly the name of the strap command being run.  Additionally, when committing 
  this file to source control, also ensure that the file's executable flag is set, for example `chmod u+x hooks/run`.

* `lib/hello.sh` is a bash script that may export shell variables and functions that can be sourced (used) by other 
  packages
  
  For example, if `lib/hello.sh` had a function definition like this:
  
      com::github::acme::hello() { 
        echo "hello"
      }
      
  other packages could *import* `hello.sh` and then they would be able to invoke `com::github::acme::hello` when they 
  wanted.
  
  We will cover how to import package library scripts soon.
  