---
# recommended 70 chars
title: "Migrating my blog from Ghost to Hugo"
# recommended 156 chars
description: "In this meta post I'll talk about my recent experience of migrating my blog from a self-hosted Ghost to Hugo."
date: 2020-12-13T14:27:00+00:00
tags: ["blogging", "ghost", "github pages", "static site generator", "hugo", "meta"]
author: "Joao Grassi"
showToc: true
TocOpen: false
draft: false
hidemeta: true
comments: false
slug: "migrating-my-blog-from-ghost-to-hugo"
type: posts

cover:
    image: "ghost-to-hugo-cover.png"
    relative: true
    alt: "Ghost > Hugo"
---

In this post I'll talk about my recent experience of migrating this very single blog from [Ghost](https://ghost.org/) to [Hugo](https://gohugo.io/).
More specifically, I want to talk about: Why I decided to migrate; What were the pain points; What were the good points and something about hosting. 

So let's start!

# Why touch something that works?

Isn't this the mantra for us, software ppl? 

Jokes aside, when I first started my blog over in 2018 (2 years already, whoa!) I did some lazy research and Ghost seemed the "cool kid on the block" at the time. I love Markdown and wanted to avoid WordPress so that settled it pretty quickly. Ghost it would be. 

Then it came to the hosting part. Because I'm ~~a cheap bastard~~ very responsible with my finances, I wanted to keep the costs as low as possible. After all, the intention of the blog **was and is** not to make a profit. I'll never include ads and spying crap here. DigitalOcean was the cheapest hosting solution I found. I was using a droplet (how they call VMs) that cost USD 6,00 per month, not bad!

I was happy with the setup. It was **super easy** to post new content. Ghost is a terrific platform and I highly recommend it. I did not decide to migrate away from it because I had problems. In fact, I had 0 problems with Ghost per se. What started to annoy me after some time and ultimately made me decide to switch was:

 - Costs
 - Maintenance

## Costs

$ 6,00 is super cheap, right? It was for me and I was happily paying it.

As I mentioned before, I'm very controlled with my finances. After a year or so of having my blog published, the monthly bills started to get on my nerves. $6,00 a month is $72,00 a year and to me, $72,00 is a lot, especially when I could have it hosted for "free" elsewhere.

## Maintenance

Since I decided to host everything on my own, I had to be also the sysadmin of the blog. In the beginning, it was kinda fun and not much work. `ssh` into the box now and then, run some `apt update` to update stuff. But there was more.

I also did backups frequently (do your backups ppl, bad things happen). I ultimately developed a script that would do everything (zip the ghost relevant folders, generate a backup from MySQL, and ship it to someplace else). But again, that took time and effort.

In the end, I was just kind of tired of doing this sysadmin work. I was there for the content and somewhat got in the middle of this other.. stuff. A few minutes per week adds up in a year. 

That's when I started to look more into static site generators.

# Overchoice - The static site generator saga

I started to notice on Twitter more and more people talking about static site generators. I knew about them and what they were there for, but nothing any more than this. At this point, I had already decided to change my blog to a static site generator. I just needed to pick one. 

One hard requirement I had was: **it must be simple**. I don't want it to become labor like it was before.

After some research, I narrow it down to these options: [Gatsby](https://www.gatsbyjs.com/), [Jekill](https://jekyllrb.com/) and [Hugo](https://gohugo.io/).

## Gatsby 

I ruled out Gatsby pretty soon. After reading a bit on forums and so on, I found out a lot of people complaining of it being very slow. It uses React which I never had the time to learn. Not yet decided, I read some more tutorials on how to set up things, and my god it all seemed so over complicated. So, yeah it was a no for Gatsby very quickly. I might be wrong and my research was just crap? 

## Jekill

I was pretty close to choosing Jekill. The only downside was that, at the time, I was still using Windows as my OS, and setting everything up was not great. I ran into a lot of errors and had to keep spending time researching solutions. This is mostly because Ruby development on Windows is not great (*I guess?*). And then, also the fact that I know 0 about Ruby. Not sure though how much one needs to know, maybe 0. But since the setup was not awesome I decided to stop and continuing shopping.

## Hugo

I was immediately happy with it. Hugo is written in Go with support for multiple platforms and they offer pre-built binaries that you just need to drop somewhere, add to your `PATH`, and boom, it works! :+1: for ease of installation.

I quickly looked into their documentation and although not everything is awesome I found it relatively easy to get started with. I also reached out in their forum when I got stuck later on and I was very well welcomed by others. +1 for docs and community support. 

Writing content is easy: You have a local server with auto-refresh running, you put your content in markdown files and repeat. When you are ready to publish, just run `hugo` and you are done. :+1: for ease of writing new content.

They also say on their website that Hugo is *"The world’s fastest framework for building websites"*. To be honest, I don't like this kind of statement, so I did some reading about why is so, and I came across some very impressive benchmarks like [this](https://www.youtube.com/watch?v=CdiDYZ51a2o&feature=emb_title) and [this](https://forestry.io/blog/hugo-vs-jekyll-benchmark/). :+1: for performance.

After all this research Hugo was the winner for me. :trophy:


# Not everything is perfect - A few bumps along the way

Hugo turned out to be pretty good from the very start, but as I got more into it, I started to bump into issues (which I expected). So let's talk about them.

## Everything starts with a good theme (or not)

After deciding on the static site generator, it was time to find a theme.

I used the official [Hugo Themes](https://themes.gohugo.io/) site to search for it. During the search, I hit several walls and was even considering abandoning it altogether. Themes not working with Hugo's latest version; Repos not actively being maintained anymore; Themes that are just very hard to extend. These were a few of the biggest things I faced.

In the end, I think it boils down to **Open source is hard**. I completely understand that the themes are free and people put their spare time into this and one should not expect (nor demand!) things to always work. I'm not blaming anyone here, especially not the theme authors, it's just that it kinda sucks.

The takeaway I took and want to share here is: Be aware that finding a theme can be a difficult task. If you have good UI/UX skills you can try to build your theme or fork and work on an existing one. Another option is to buy a theme and get guaranteed support/updates. There are options out there.

In my case, I was lucky to find the awesome [Hugo PaperMod](https://github.com/adityatelange/hugo-PaperMod) theme from [adityatelange](https://github.com/adityatelange) (thank you! :star2:) which worked perfectly for what I needed and has the right amount of customization options and I intend to contribute to it and be around to help as much as I can. 

> And for Pete's sake, if you are an organization making money from your site that uses an open-source theme, **be a decent person/company and give some of that money to the author**. Show you appreciate their work (Yes, OSS ppl also like money). If you can't donate, maybe then try to help maintain the theme you decided to use. It's just fair and everyone wins this way.

The next big thing to deal with was around [backward compatiblity](https://en.wikipedia.org/wiki/Backward_compatibility) (URL wise).

## Existing URLs - How to not break them?

Great, I finally have a working Hugo site with a theme. It's time to start migrating the content. That brings us to an important part of the process: Existing URLs. 

In my case, I had to consider the following ones:

- Post URLs
- Social media post images (Open Graph/Twitter meta tags)
- RSS feed

### Post URLs

The posts in my Ghost blog followed this simple structure: `blog.joaograssi.com/<post-title>`, meaning the post "permalink" is directly after the domain. After I moved the first post to Hugo I noticed that the URL being generated was something like this: `blog.joaograssi.com/posts/some-title`

Then I sat down and read the documentation on [URL Management](https://gohugo.io/content-management/urls/) (do this first, don't do it like me :sweat_smile:) and then all made sense. There's a lot more to it of course, but Hugo generates the URLs based on the actual folder they are in (remember this is a static site generator!). What does this mean you ask? Well, say you have a structure like this in your site:

```
site/
├─ content/
│  ├─ posts/
│  │  ├─ my-first-post.md ## your post here
```

The URL for `my-first-post.md` will be: `mysite.com/posts/my-first-post`. As we saw, this is not the same as my existing post URLs, so I needed to fix it.

Luckly Hugo offers many alternatives to solve this. One alternative is to set the [URL directly into front matter](https://gohugo.io/content-management/urls/#set-url-in-front-matter) and that's what I used.

For example, one of my posts has this URL: url: `blog.joaograssi.com/asp-net-core-integration-tests-with-docker-compose-azure-pipelines`. In the markdown file for the post I just had to do this:

```
---
# other things here...

url: asp-net-core-integration-tests-with-docker-compose-azure-pipelines
---
```
That's it. The post is avaiable at the same URL as before!

> Although this works, when you publish the site all these posts will be at the root of your `publish` folder. If you are migrating a lot of posts the folder can be quite messy. Since I didn't have many I was okay with it and moving forward I'll keep the posts in the `posts/` structure. This makes the `publish` folder much cleaner.

### Open Graph image URLs

The next URL to manage is the URL for the images used when sharing the posts on social media. These are present in `meta` tags. In my case these were [Open Graph tags](https://ogp.me/) and [Twitter card tags](https://developer.twitter.com/en/docs/twitter-for-websites/cards/guides/getting-started). 

> If you don't use these or you don't care about previously shared posts on social media you can skip this.

In Ghost the images you upload end up in a certain folder organized by year and month. For example, I have a post with a "cover" image in this URL:
`blog.joaograssi.com/content/images/2020/08/using-docker-compose-for-your-asp-net-ef-core-integration-tests.jpg`. 

To not break the existing shared posts, I had to make sure the images for the meta tags were published at the same URL. The way you can do this is by using the `static` folder in your Hugo site. 

Whatever you put inside your `static` folder is going to be published at the root of your site. To replicate the URL above I had to place the image exactly in this structure:

```
site/
├─ content/
├─ static/
│  ├─ content/
│  │  ├─ images/
│  │  │  ├─ 2020/
│  │  │  │  ├─ 08/
│  │  │  │  │  ├─ using-docker-compose-for-your-asp-net-ef-core-integration-tests.jpg
```

When the site is published the image is accessible as it was before. Sweet!

> When using Ghost I didn't control where the images were placed. With Hugo you have much more control over this. From now on I will just put whatever resource the post needs (images and etc) close to it.

The last thing to deal with is the RSS feed URL.

### RSS feed URL

Hugo generates the RSS `.xml` files for you automatically when you build your site. They are generated for each section of your site. Home, posts, tags, etc. But there is a catch: The RSS URL is always like `https://yoursite.com/index.xml`. 

The existing RSS URL of my blog with Ghost was just `https://yoursite.com/rss`. I needed to find a way to fix this, otherwise, all subscribers would need to get the new URL, which is bad. 

After researching, I found this post with the same question: [How can I change the RSS URL?](https://discourse.gohugo.io/t/how-can-i-change-the-rss-url/118/6). 

The way to solve it is to use Hugo's [Custom output formats](https://gohugo.io/templates/output-formats#readout) and [Media types](https://gohugo.io/templates/output-formats/#media-types). There were two issues for me: 

1. The URL was not compatible with my previous (index instead of rss)
2. The `.xml` extension was required in the URL

After reading the docs and the forum post above, this is what I modified in my `config.yml`:

```yml
# 1 - Redefine the 'baseName' of the default RSS output format from index to rss
outputFormats:
  RSS:
    mediatype: "application/rss"
    baseName: "rss"

# 2 - Remove the suffixes from the `application/rss` media type
mediaTypes:
    application/rss:
      suffixes: []
```
With this simple change, I have now the RSS base feed on the same URL as before. :smiley:

> Hugo ships with [its own RSS 2.0 template](https://github.com/gohugoio/hugo/blob/master/tpl/tplimpl/embedded/templates/_default/rss.xml) and it works fine except for one thing: It does not include the post full content in the xml. The good thing is that [you can extend it](https://gohugo.io/templates/rss/#lookup-order-for-rss-templates) and add what you want. Here's how I extended mine to include the full content: [index.rss.xml](https://github.com/joaopgrassi/blog/blob/main/src/layouts/index.rss.xml#L36).

Alright! All issues are taken care of. Time to ship it! :rocket:

# Hosting

Initially, I wanted to use Netlify. It has a "free" plan and I liked the fact I could have CI builds to auto-publish on each commit. I then started doing some research around Netlify and I came across some things that ultimately made me decide against it. These were:

- I manage my DNS entries on Cloudflare. To use Netlify I would need to move the DNS config there (at least for the blog sub-domain).
- Although there's a free plan on Netlify, I discovered that if my site goes viral out of a sudden (or maybe a directed attack?) I would exceed the quota and be charged for it.

It all goes back again to the same two things: **Costs and Maintenance**. 

I didn't want to move my DNS entries from Cloudflare to Netlify and have two places to manage them. I also read that since Netlify [holds their own cache](https://www.netlify.com/blog/2017/03/28/why-you-dont-need-cloudflare-with-netlify/) (which makes sense), it somehow conflicts with Cloudflare's cache. There are ways around it, but again, this just equals more work.

Then there's the cost thing. What happens if my site goes viral or I get attacked? While searching I found this post: [Limit bandwidth to avoid high billing caused by DDoS?](https://community.netlify.com/t/limit-bandwidth-to-avoid-high-billing-caused-by-ddos/13086/3) and I got a bit scared with the response there. Don't get me wrong, I understand the reason why and it's fair. But I didn't want to have a surprise with a big bill. I would be fine if the site stopped working if I reach the quota, but that's not what happens there.

GitHub pages it would be then.

## GitHub pages

I decided then to just use GitHub pages. I'm already using it for my root domain (https://joaograssi.com), I could continue using Cloudflare and no surprise bills:

> If your site exceeds these usage quotas, we may not be able to serve your site, or you may receive a polite email from GitHub Support or GitHub Premium Support suggesting strategies for reducing your site's impact on our servers, including putting a third-party content distribution network (CDN) in front of your site, making use of other GitHub features such as releases, or moving to a different hosting service that might better fit your needs. [^1].

The high-level setup is like this:

- GitHub repo for the blog source files on the `main` branch
- A `gh-pages` branch for the published site with a `CNAME` file containing the subdomain `blog.joaograssi.com`
- My root domain `joaograssi.com` already pointed to my `joaopgrassi.github.io` (GitHub user page), so I only needed to point the `blog` subdomain to my main domain `joaograssi.com` on Cloudflare and GitHub takes care of the rest (via the `CNAME` file for the `blog` sub-domain)

There are multiple other ways to [host a Hugo site on GitHub](https://gohugo.io/hosting-and-deployment/hosting-on-github/). Check the documentation page to learn about other options.


> Trick: Since you need the `CNAME` for the custom domain in your GitHub repo, you can put it inside the Hugo `static` folder. As we've seen, the file will be placed at the root when you publish your site.
 # Summary

In this post, I went through my experience of migrating my blog from Ghost to Hugo. I highlighted the good and bad parts about the process, the options I considered, and why I ultimately decided to use Hugo as my static site generator.

I continued then explaining the challenges related to backward compatibility (existing URLs and so on) and how I solved them. Lastly, I showed the approach I used to host the blog on GitHub pages.

I hope this was useful to you. Happy blogging!

Bye 2020.

 [^1]:[GitHub Pages - Usage limits](https://docs.github.com/en/free-pro-team@latest/github/working-with-github-pages/about-github-pages#usage-limits)