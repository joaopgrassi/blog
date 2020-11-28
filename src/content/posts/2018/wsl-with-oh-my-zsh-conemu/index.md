---
title: "Setting up Windows Subsystem for Linux with zsh + oh-my-zsh + ConEmu"
description: "Learn how to setup up Windows Subsystem for Linux with Oh My Zsh and ConEmu plus some cool themes and colors!"
date: 2018-04-29T15:22:00+00:00
tags: ["asp.net-core", "linux", "oh-my-zsh", ".net-core"]
author: "Joao Grassi"
showToc: false
TocOpen: false
draft: false
hidemeta: true
comments: false
url: windows-subsystem-for-linux-with-oh-my-zsh-conemu
type: posts

resources:
- src: 'broken-theme.png'
- src: 'install-oh-my-zsh.png'
- src: 'working-theme.jpg'
- src: 'zsh-final.png'

cover:
    image: "ms-loves-linux-cover.png"
    relative: true
    alt: "Microsoft <3 Linux"
---

The era of .NET developers being constrained on using only Windows as a platform is gone. (At least for ASP.NET). That might be very cool to some, but also scary for others. Fear of change [is true](https://www.huffingtonpost.com/heidi-grant-halvorson-phd/why-we-dont-like-change_b_1072702.html). Nevertheless, it's definitely time (if not yet) to get out of the comfort zone and get your feet wet. Being able to work with .NET on Linux/Mac is one of the points that makes me agree 100% with Nick Craver that [.NET Core is the future](https://twitter.com/Nick_Craver/status/990317621559156736).

After reading [Scott Hanselman's blog post](https://www.hanselman.com/blog/SettingUpAShinyDevelopmentEnvironmentWithinLinuxOnWindows10.aspx) last week, I decided to setup WSL on my laptop. If you don't know what Windows Subsystem for Linux is (**WSL** from now on in this post), I recommend reading [this](https://docs.microsoft.com/en-us/windows/wsl/about/) before.

The TL;DR of that link is: 
> WSL lets developers run Linux environments -- including most command-line tools, utilities, and applications -- directly on Windows, unmodified, without the overhead of a virtual machine.
> 

While setting it up on my machine was very easy, I didn't want to stay with the boring Windows bash shell. Guys at work use Mac's with *oh-my-zsh* and boy that made me pretty jealous. It was not that straightforward to make it all work though. So hopefully, this post will help me and others in the future. Here's what we are going to do:

* Enable WSL on Windows 10
* Install zsh + oh-my-zsh
* Configure zsh and oh-my-zsh
* Change Themes and colors
* Adding Bash on Ubuntu task in ConEmu* 

## Enable WSL on Windows 10

This is pretty straightforward to set up, Just follow the instructions [here](https://docs.microsoft.com/en-us/windows/wsl/install-win10) to get Ubuntu running. After you are in, update the packages, by running:  `sudo apt-get update`. When all is working, you can continue to the next step.

## Installing zsh

Open the Ubuntu app installed from the App Store. We will now install zsh:

```bash
sudo apt-get install zsh
```

After installing it, type `zsh`. zsh will ask you to choose some configuration. We will do this later on while installing `oh-my-zsh`, so choose option `0` to create the config file and prevent this message to show again.

## Installing oh-my-zsh

Before all we need to have `git` installed:

```bash
sudo apt-get install git
```

Then, use `curl` to install oh-my-zsh:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
```

This will clone the repo and replace the existing `~/.zshrc` with a template from `oh-my-zsh`.

{{< img "*install-oh-my-zsh*" "Installing oh-my-zsh" >}}

## Configuring zsh/oh-my-zsh

First, we need to make sure `zsh` is executed by default for Bash on Ubuntu. This is not mandatory, but if not done you need to type `zsh` every time. For this, edit the `.bashrc` file with nano: `nano ~/.bashrc ` and paste this right after the first comments:


```bash
if test -t 1; then
exec zsh
fi
```

Save it ` Ctrl + shift X` and restart your Ubuntu shell. You should be on zsh by default now.

## Changing the Theme of oh-my-zsh

oh-my-zsh has several nice Themes. It's worth checking them out. For this tutorial, I'm going to use the awesome [agnoster](https://github.com/agnoster/agnoster-zsh-theme). 

Edit the `~/.zshrc` again with nano: `nano ~/.zshrc`:

```bash
# Find and change this
ZSH_THEME="robbyrussell"

# To this
ZSH_THEME="agnoster"
```

Save it and restart your Ubuntu shell again. 

{{< img "*broken-theme*" "Broken theme" >}}

Now was the tricky part while I was doing this on my laptop. After installing the theme, I got a totally broken shell (as shown in the image), with weird fonts and missing icons. That was expected due to missing Powerline Fonts, but even after installing them on Ubuntu the Theme was still broken. I tried several things and couldn't make it work. Since we will run it with ConEmu, I didn't want to spend more time on it. The Ubuntu shell is very limited anyway so.. not a big deal.

## Installing missing Powerline Fonts

We need to install the Powerline fonts in our Windows to make the agnoster theme work. Follow these steps:

1. Clone the powerline repository on Windows

```bash
git clone https://github.com/powerline/fonts.git
```

2. Open an admin PowerShell, navigate to the root of the repo and run this:

```bash
.\install.ps1
```

This will install all the fonts on your Windows. You might get an error from PowerShell blocking you from running the script. Check [this out](https://stackoverflow.com/questions/4037939/powershell-says-execution-of-scripts-is-disabled-on-this-system) if it happens with you. Make sure to reverse the policy after.

## Changing directory colors

The directory colors for zsh is awful. If you followed along, by now you should have an ugly yellow or dark blue background on folders when `ls/ll`. Luckily, we can change that by installing a Solarized Color Theme from [here](https://github.com/seebi/dircolors-solarized). Follow these steps:

1. Pick a theme from the GitHub repo (I'm using dircolors.ansi-dark since I use a dark shell).
2. Download the file making sure to put it in the user's home:

```bash
# using dircolors.ansi-dark
curl https://raw.githubusercontent.com/seebi/dircolors-solarized/master/dircolors.ansi-dark --output ~/.dircolors
```

3. Edit your `~/.zshrc` and paste this:

```bash
## set colors for LS_COLORS
eval `dircolors ~/.dircolors`
```
    
We have nice colors now :)
{{< img "*working-theme*" "Adding directory colors" >}}

## Setting Bash on Ubuntu task in ConEmu

Open ConEmu, and go to `Settings`. Navigate on the left-menu: `Startup > Tasks`. There, click at the `+` button at the bottom.

1. Add a name for the task. Anything will suffice. I used `bash::ubuntu` to group Ubuntu into the bash tasks.
2. On `Task parameters` choose an icon for the task. I picked the Ubuntu icon app that is buried under some very long path. but any .ico will work. You can leave it blank if you don't care.
3. For the `command` use this `%windir%\system32\bash.exe ~ -cur_console:p`. This will start bash under the user home directory. Since we already configured `zsh` to run by default, this is enough.

Open the new task on ConEmu and... Voalá!
{{< img "*zsh-final*" "View of the terminal configured" >}}

Nice command look, lots of git shortcuts and much more productivity. Couldn't enjoy this more.

## Additional links

Here are a few other things you might want to look:

* [oh-my-zsh cheatsheet](https://github.com/robbyrussell/oh-my-zsh/wiki/Cheatsheet): Lots of commands to improve your productivity
* [Colors page on ConEmu](https://conemu.github.io/en/SettingsColors.html): How to change ConEmu color scheme (If you liked mine, I'm using Solarized (Luke Maciak) with Meslo LG M DZ for Powerline console font)
* Understand why you're not supposed to touch Linux files using Windows apps: https://blogs.msdn.microsoft.com/commandline/2016/11/17/do-not-change-linux-files-using-windows-apps-and-tools/

Would be cool to see what other things you use on your setup. Just let me know in the comments! 
