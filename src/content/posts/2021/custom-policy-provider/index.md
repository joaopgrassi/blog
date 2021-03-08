---
# recommended 70 chars
title: "Protecting API endpoints using policy-based authorization in ASP.NET Core"
# recommended 156 chars
description: "In this post we'll continue where we left off and use the permission identity we created to authorize our API endpoints by using a custom policy provider."

date: 2021-03-08T16:30:00+00:00
tags: ["asp.net-core", "authorization", "security", "permissions", "policy-provider"]
author: "Joao Grassi"
showToc: true
TocOpen: false
draft: true
hidemeta: true
comments: false
slug: "asp-net-core-permission-based-custom-policyprovider"
type: posts
series: ['Authorization in ASP.NET Core']

cover:
    image: "post-cover.png"
    relative: true
    alt: "No trespassing sign"
---

This is the second post in the [Authorization in ASP.NET Core](/series/authorization-in-asp.net-core) series.

- [Part 1: Using a middleware to build a permission-based identity in ASP.NET Core](/posts/2021/asp-net-core-permission-based-authorization-middleware)

- [Part 2: Permission-based authorization using a custom Policy Provider in ASP.NET Core](/posts/2021/asp-net-core-permission-based-custom-policyprovider)


In the previous post we set the foundation by creating a `ClaimsIdentity` containing all the logged-in user permissions with the help of a custom middleware.

In this post, we'll see what options does the framework offers for authorization and how we can combine those with the permission-based identity to protect our API endpoints in a nice way. Let's start!


## The basics

> Skip to the next session if you know about Depedency injection and Middlewares in ASP.NET Core.


Before we start going into the options for authorization, I'd like to talk about the `AddAuthentication` and `AddAuthorization` methods we see often in `ConfigureServices` and their counterpart `UseAuthentication` and `UseAuthorization` in `Configure`, all inside `Startup.cs`.

### ConfigureServices

Mostly everything we do inside `ConfigureServices` has to do with dependency injection. Here we have the opportunity to register all the things we will be using across our application via DI.

When we talk about authentication and authorization, you always see the "combo" in there, but what is the deal with them? 

- `AddAuthentication`: Calling this will register all the base stuff related to authentication, including the appropriate authentication handler. You can check the source file here to see in details: [AuthenticationServiceCollectionExtensions](https://github.com/dotnet/aspnetcore/blob/c925f99cddac0df90ed0bc4a07ecda6b054a0b02/src/Security/Authentication/Core/src/AuthenticationServiceCollectionExtensions.cs#L21).


- `AddAuthorization`: This one is more relevant to this series. Calling this method will end up calling [AddAuthorizationCore](https://github.com/dotnet/aspnetcore/blob/c925f99cddac0df90ed0bc4a07ecda6b054a0b02/src/Security/Authorization/Core/src/AuthorizationServiceCollectionExtensions.cs#L21), which registers a bunch of stuff, but I want you to pay attention to this line:

```
services.TryAdd(ServiceDescriptor.
    Transient<IAuthorizationPolicyProvider, DefaultAuthorizationPolicyProvider>());
```
This adds the `DefaultAuthorizationPolicyProvider` which will be important for us later. 

### Configure

Inside `Configure` we configure the pipeline of our application (AKA middleware). For example we have `app.UseRouting()` which ends up calling `builder.UseMiddleware<EndpointRoutingMiddleware>()`.

The key takeway from `Configure` is: **order matters**. Here we are configuring the pipeline of our app.

When a request arrives, each middleware is invoked in the order they were added inside `Configure`. When the request is returning, it then passes back again in reverse (stack). The official docs explains it very well, so definetely check it out: [Middleware order](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/middleware/?view=aspnetcore-5.0#middleware-order)

Now that we know this, it should make more sense why in the last post our `Configure` method looked like this:

```csharp
// the rest is omitted for brevity
app.UseAuthentication();
app.UseMiddleware<PermissionsMiddleware>(); // our custom permission middleware
app.UseAuthorization();
```

Because our `PermissionsMiddleware` needs the logged-in user, it has to be added **after** `UseAuthentication` otherwise we wouldn't have the user inside our middleware as login would happen later. Similarly, we can't add `UseAuthorization` before any of those for similar reasons.


I wanted to touch on this, because speacially for newcomers it's easy to just copy and paste stuff from the web without knowing what it does or why it's necessary. Hopefully this clears it a bit. If you still want to know more, follow the code on GitHub fore more goodness :).

## Policy based authorization

- discuss what claims/policy/role are and their limitation (not dynamic)
- discuss the basics types that compose policy-base authz: Requirements, Handlers and Policy Provider

## Dynamic policies

- Shows how to create dynamic policies


[Photo by Dimitri Houtteman](https://unsplash.com/@dimhou?utm_source=unsplash&amp;utm_medium=referral&amp;utm_content=creditCopyText) on [Unsplash](https://unsplash.com/?utm_source=unsplash&amp;utm_medium=referral&amp;utm_content=creditCopyText)