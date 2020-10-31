---
title: "Launching Env-Guard: No more mistakes in production!"
date: 2018-02-19T19:58:00+00:00
tags: ["env-guard", "front-end", "chrome-extension"]
author: "Me"
showToc: false
TocOpen: false
draft: false
hidemeta: true
comments: false
url: launching-env-guard
type: posts
---

It has been almost two months now since I uploaded my first Chrome extension to the Chrome Store. And now, I **finally** have a Blog where I can officially talk about it with the world!

## TL;DR
I have built a Chrome Extension to help developers avoid making mistakes while dealing with "Production Like" instances of their apps. [Click here to see the links](#conclusion)


## The problem

My friends and I work in a Web application that is mainly an internal administration tool. The application does all sorts of complicated things and touches several domains within the company. 
In a normal day at work, we develop against our `Local` version of the app. Then, when we want to test it, we deploy it to a  `QA` environment. When all is good and tested, we deploy to `Staging` and finally to `Production`. So, doing the math, we have **4** environments where our app runs. And.. it looks **exactly** the same in all of them.

If you are following with me you probably see where I'm going with this. In our current setup, it's pretty darn easy to change things in the application thinking you were in a "safe" environment, but it turns out you were actually in Production. *Sigh

## Introducing Env-Guard

We thought: Wouldn't be nice if we could easily identify at which environment we are looking at? Something similar as you can do on SSMS on the [Query Tabs](https://solutioncenter.apexsql.com/wp-content/uploads/2017/10/word-image-58.png) when fiddling around production databases (scared).

So, I decided to create a Chrome Extension! In the end what I wanted was to change the Chrome Tab based on the URL. The Tab should be modified in some way that would enables us to easily distinguish between our environments.

## How it works

The idea is pretty simple: You create *Rules* for your environments. A Rule contains a combination of fields that are used to identify and later modify the Chrome Tab associated with your app. The most important parts of a Rule are the `URL` and the `Operator` fields: 

* **URL**: This is just a text. It can be a full URL or parts of it. 

* **Operator**: The operator is what the extension will use combined with the URL provided to find the tab. The extension acts on the `location.href` and applies the operators on it. If it matches, then we have a Rule to apply! An example of an Operator could be `Starts With` or a `Regex expression`. The extension supports more, of course.

![A screenshot of the URL operator in action](/posts/2018/url_operator.jpg "URL operator")


## What can I customize on my Tab?

The most important requirement for us at least, was to be able to look at a Tab and know immediately which Environment it belongs to. My initial idea was to change the background color of the whole tab, but I soon discovered that Chrome does not allow it. Bummer. 

What we could do then? Basically 3 things:

* Change the favicon
* Change the Tab Title
* Add some banner on the top of the page, with some very extravagant color and text

All of this so we could do this at the end:

![Simulating a production website](/posts/2018/prod_google.jpg "Simulating a production website")


Pretty cool, huh? Of couse, you don't have to use all three customizations. You can pick them as it make sense for you.

## <a name="conclusion"></a>Conclusion


I had a lot of fun building this. It was my first Chrome Extension and I learned a bunch along the way. Plus, it saved me (and hopefully others) from making mistakes in Production.
Basically, the main technologies/frameworks I used were:
* [Angular](https://github.com/angular/angular) + [Material](https://github.com/angular/material2)
* [@ngrx/store](https://github.com/ngrx/store)

The extension is open source and it is avaiable on Github. I'm open for contributions and improvements. There's still a lot to do :)

Here are the links: [Github Repo](https://github.com/joaopgrassi/env-guard), [Chome Store](https://chrome.google.com/webstore/detail/env-guard/hldheamjpbaceigalkfkjogkfofankpp)

When I started developing this, I found another very similar extension called [Tab Modifier](https://github.com/sylouuu/chrome-tab-modifier). It has the same concept but contains way more features than mine, because of that it can be used in many other ways. Env-Guard is developer "oriented" and will always have this constraint. I plan to only add features that make sense to us.
So, if you want to modify your tabs definitely check this one out. And thanks [@sylouuu](https://github.com/sylouuu) for understanding the goals of my extension.

That's it for now. 
