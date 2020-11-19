---
title: "Encapsulating getting access tokens from IdentityServer with a typed HttpClient and MessageHandler"
description: "Learn how to use the HttpClientFactory in conjunction with typed HttpClients and MessageHandlers to get access tokens implicitly from IdentityServer."
date: 2019-03-06T21:57:00+00:00
tags: ["asp.net-core", ".net-core", "identityserver", "httpclientfactory", "httpclient", "accesstokens", "oauth"]
author: "Joao Grassi"
showToc: false
TocOpen: false
draft: false
hidemeta: true
comments: false
url: typed-httpclient-with-messagehandler-getting-accesstokens-from-identityserver
type: posts

images:
- typed-httpclient-with-messagehandler-getting-accesstokens-from-identityserver/barbed-wire-on-green-background-cover.jpg

resources:
- src: 'client_credentials_flow-1.svg'
- src: 'phone-call-diagram-2.svg'
---

Recently, I had to interact with an external API which is protected by JWT Bearer Tokens. For this, I had to get an access_token first and then set it to each request. But, this can get quite tedious very soon even if you just do it a few times. In the end, I wanted an implementation that encapsulated the need for developers to worry about getting access tokens prior to communicating with the API.

In this post I'll demonstrate how we can use the HttpClientFactory introduced back on ASP.NET Core 2.1 in conjunction with typed HttpClients and MessageHandlers, to achieve a nice and easy API abstraction over an external service.

Aside: If you don't know what a HttpClientFactory is I strongly recommend you to read Steve Gordon's series about it: HttpClientFactory in ASP.NET Core 2.1. Steve does a very good job on explaining what problems the factory solves and why you should care about it. Even if you are not using .ASP.NET Core I still recommend it, because it boils down to the issue we long have with the HttpClient class. Pause, go there and read it. Then come back here to (hopefully) learn more :)

## The applications used to demonstrate this post

In more detail, the scenario I described before is comprised of the following applications:

1. The Identity Provider (Going to use IdentityServer4)

2. An API which is protected by JWT tokens (still under our control, but as a completely separated service)

3. The "client" API which needs to get data from the protected API. 

Graphic representation always helps in understanding how things are tied together. So, here's is an image that represents the flow of requests between the applications laid out above:

{{< img "*client_credentials_flow-1*" "How the apps communicate between themselves" >}}

If you are familiar with OAuth, you might recognize the flow above. Basically, we are going to communicate with our Protected API via the [OAuth 2.0 Client Credentials Grant Type](https://tools.ietf.org/html/rfc6749#section-4.4)

All the code used in this post is available on GitHub: [httpclient-token-identityserver](https://github.com/joaopgrassi/httpclient-token-identityserver)


## Talking to our protected API

It's time to dig into the code. I'll guide you through the approaches that we can use to talk with our "Protected API", starting from the most simple and obvious one (not great, BTW) and, step-by-step we'll improve it until we reach a nice and clean design. (at least I think so)

>**Note**: I'll be using the [IdentityModel](https://identitymodel.readthedocs.io/en/latest/) NuGet package during this post. This is a very neat package that makes the interaction with Identity Server extremely easy by the use of extension methods on `HttpClient`. You are not required to use it, but you'll have to write more code on your own :)

Let's remember what we have to do before we can consume our "Protected API"

1. We need to get a hold of the credentials of our API (remember we are a "client")
2. We need to authenticate with Identity Server (using the credentials above) in order to obtain an `access_token`
3. We need to set the `access_token` in the `Authorization: Bearer <token>` request header 
4. Send the request to our Protected API


### Attempt 1 - "Works but it's not great" approach

```csharp{.line-numbers}
[HttpGet("version1")]
public async Task<IActionResult> GetVersionOne()
{
    // 1. "retrieve" our api credentials. This must be registered on Identity Server!
    var apiClientCredentials = new ClientCredentialsTokenRequest
    {
        Address = "http://localhost:5000/connect/token",

        ClientId = "client-app",
        ClientSecret = "secret",

        // This is the scope our Protected API requires. 
        Scope = "read:entity"
    };

    // creates a new HttpClient to talk to our IdentityServer (localhost:5000)
    var client = new HttpClient();

    // just checks if we can reach the Discovery document. Not 100% needed but..
    var disco = await client.GetDiscoveryDocumentAsync("http://localhost:5000");
    if (disco.IsError)
    {
        return StatusCode(500);
    }

    // 2. Authenticates and get an access token from Identity Server
    var tokenResponse = await client.RequestClientCredentialsTokenAsync(apiClientCredentials);
    if (tokenResponse.IsError)
    {
        return StatusCode(500);
    }

    // Another HttpClient for talking now with our Protected API
    var apiClient = new HttpClient();

    // 3. Set the access_token in the request Authorization: Bearer <token>
    client.SetBearerToken(tokenResponse.AccessToken);

    // 4. Send a request to our Protected API
    var response = await client.GetAsync("http://localhost:5002/api/protected");
    if (!response.IsSuccessStatusCode)
    {
        return StatusCode(500);
    }

    var content = await response.Content.ReadAsStringAsync();

    // All good! We have the data here
    return Ok(content);
}
```
This works but it's not optimal. A few problems:
1. Our credentials are hardcoded and created "on-the-fly"
2. We create two `HttpClient`s every time this endpoint is hit

If you've read Steve's series mentioned earlier (or you already know the issue), you should have a guess on what's wrong with this approach, right?

### Attempt 2 - Creating a typed `HttpClient` for Identity Server

Every time we need to get an `access_token` we'll have to do the same code from step 1 and 2. We can refactor that using the `HttpClientFactory` and typed `HttpClient` introduced in ASP.NET Core 2.1. 

**Our Typed Identity Server client:**
```csharp{.line-numbers}
public interface IIdentityServerClient
{
    Task<string> RequestClientCredentialsTokenAsync();
}

public class IdentityServerClient : IIdentityServerClient
{
    private readonly HttpClient _httpClient;
    private readonly ClientCredentialsTokenRequest _tokenRequest;
    private readonly ILogger<IdentityServerClient> _logger;

    public IdentityServerClient(
        HttpClient httpClient, 
        ClientCredentialsTokenRequest tokenRequest,
        ILogger<IdentityServerClient> logger)
    {
        _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
        _tokenRequest = tokenRequest ?? throw new ArgumentNullException(nameof(tokenRequest));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async Task<string> RequestClientCredentialsTokenAsync()
    {
        // request the access token token
        var tokenResponse = await _httpClient.RequestClientCredentialsTokenAsync(_tokenRequest);
        if (tokenResponse.IsError)
        {
            _logger.LogError(tokenResponse.Error);
            throw new HttpRequestException("Something went wrong while requesting the access token");
        }
        return tokenResponse.AccessToken;
    }
}
```

The code above is just an Interface and an implementing class that exposes one method: `RequestClientCredentialsTokenAsync`. It gets an `access_token` from Identity Server and returns it, very simple. This class also gets by the DI container an instance of `ClientCredentialsTokenRequest` which contains our credentials, so no more hardcoded stuff. 

You might have noticed also the `HttpClient` injected into the constructor. This `HttpClient` is provided by the DI container to us and it's "pre" configured. We'll see how that works next.

**How to register our typed HttpClient**

Now that we have our `IdentityServerClient` class ready, we need to register it within the DI container so we can request it later. This happens in our `Startup.cs` and more specifically in the `ConfigureServices` method:

```csharp{.line-numbers}
public void public void ConfigureServices(IServiceCollection services)
{
    services.AddMvc().SetCompatibilityVersion(CompatibilityVersion.Version_2_2);

    services.AddSingleton(new ClientCredentialsTokenRequest
    {
        Address = "http://localhost:5000/connect/token",
        ClientId = "client-app",
        ClientSecret = "secret",
        Scope = "read:entity"
    });

    services.AddHttpClient<IIdentityServerClient, IdentityServerClient>(client =>
    {
        client.BaseAddress = new Uri("http://localhost:5000");
        client.DefaultRequestHeaders.Add("Accept", "application/json");
    });
}
```

At line `5` we register our `ClientCredentialsTokenRequest` as a Singleton. In a real-world app you would most likely read these values from `appsettings.json`, but to keep it simple we'll leave it that way.

Between lines `13-17` is where the "magic" happens. We call the `AddHttpClient` extension method on `IServiceCollection` which in this case is adding a **typed** `HttpClient`. The `AddHttpClient` provides an overload where you can pass an `Action<HttpClient>` **and pre-configure the HttpClient that will get injected into this class**. Here we are setting the `BaseAddress` of our IdentityServer and some default request headers. Now, every time I request an `IIdentityServerClient` I'll get a `HttpClient` pre-configured with those values.



> There are other ways of registering Http clients. For instance, you could add a **named** client like `AddHttpClient("MyClient")`. I tend to prefer strongly typed ones as they provide a more constrained API plus I avoid magic strings in my code.

With our typed `IdentityServerClient` created and configured, let's refactor our controller.

```csharp{.line-numbers}
private readonly IIdentityServerClient _identityServerClient;

public ConsumerController(IIdentityServerClient identityServerClient)
{
    _identityServerClient = identityServerClient;
}

[HttpGet("version2")]
public async Task<IActionResult> GetVersionThree()
{
    // uses our typed HttpClient to get an access_token from identity server
    var accessToken = await _identityServerClient.RequestClientCredentialsTokenAsync();

    // the rest is the same as in version1
    var apiClient = new HttpClient();
    apiClient.SetBearerToken(accessToken);

    var response = await apiClient.GetAsync("http://localhost:5002/api/protected");
    if (!response.IsSuccessStatusCode)
    {
        Console.WriteLine(response.StatusCode);
        return StatusCode(500);
    }
    var content = await response.Content.ReadAsStringAsync();
    return Ok(content);
}
```

Now our `ConsumerController` takes a dependency on `IIdentityServerClient`. Next, I added a new `version2` endpoint which basically is a copy from `version1` but without all the code that dealt with getting a token. That now is just **one line**. So much cleaner isn't it?!

When we call `_identityServerClient.RequestClientCredentialsTokenAsync()` in our `verison2` endpoint, the framework will inject the `ClientCredentialsTokenRequest` singleton that we configured into the `IdentityServerClient` class and it will proceed to get and return the `access_token` from Identity Server. 

I think this version is way better than the first one. But we still create a new `HttpClient` for talking to our protected API. Let's see how to fix that in the next step.

### Attempt 3 - Creating a typed `HttpClient` for our Protected API

Now that we have seen how we can create and use a typed HttpClient, we can use the same approach and create a typed for our "Protected API". A quick implementation looks like this:

```csharp{.line-numbers}
public class ProtectedApiClient : IProtectedApiClient
{
    private readonly IIdentityServerClient _identityServerClient;
    private readonly HttpClient _httpClient;

    public ProtectedApiClient(
        HttpClient httpClient, 
        IIdentityServerClient identityServerClient)
    {
        _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
        _identityServerClient = identityServerClient 
            ?? throw new ArgumentNullException(nameof(identityServerClient));
    }

    public async Task<string> GetProtectedResources()
    {
        // code to obtain and set the access_token in the header
        var accessToken = await _identityServerClient.RequestClientCredentialsTokenAsync();
        _httpClient.SetBearerToken(accessToken);

        // request data from our Protected API
        var response = await _httpClient.GetAsync("/api/protected");
        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine(response.StatusCode);
            throw new Exception("Failed to get protected resources.");
        }
        return await response.Content.ReadAsStringAsync();
    }
}
```

Nothing special going on here. Since we need to get tokens, we take a dependency on `IIdentityServerClient` and we receive our typed `HttpClient` which was configured exactly as before. 

Let's enumerate what we have improved so far:

1. Both clients are now managed by the `HttpClientFactory`. No more `new HttpClient()` in our code!

2. We have strongly typed interfaces that makes communicating with external services much easier (plus is so much more readable than looking and finding HttpClients all over the place)

But, we can improve this further. We can encapsulate the code for getting an `access_token` and remove that code from our `ProtectedApiClient`. We can achieve this by using `Message Handlers`.

### Attempt 3.1 - Using Message Handlers with our typed `HttpClient`

We can make the "experience" of talking with our protected API via our typed client even better. Right now, we still have to worry about getting an `access_token` prior to actually doing what we need to do. In this case, getting a token prior to sending a request is what is known as a *cross-cutting* concern and Message Handlers are especially useful for cases like this.

Message Handlers have been around for some time now, so they are not something new or exclusively related to .NET Core. Here's a definition (from 2012!) for it from [docs.microsoft.com](https://docs.microsoft.com/en-us/aspnet/web-api/overview/advanced/httpclient-message-handlers)

>A message handler is a class that receives an HTTP request and returns an HTTP response. Typically, a series of message handlers are chained together. The first handler receives an HTTP request, does some processing, and gives the request to the next handler. At some point, the response is created and goes back up the chain. This pattern is called a delegating handler.

Okay, this definition can be somewhat confusing and hard to absorb if you've never heard of it before. Analogies help me on bringing things into perspective, so perhaps this one might help you grasp the idea. You can skip to the next part if you want.

Imagine a scenario where you received your internet bill and it is $100 bucks more expensive than usual. You want to call the provider to straight things up. Your end goal is to talk to the manager in charge. Here's a typical result of such a call:

{{< img "*phone-call-diagram-2*" "Complaining over the phone - an analogy to message handlers" >}}

Hopefully, this made things clearer?. In the flow above:

1. **You** (client) is who fired the "request". Your request is picked up by the **1st contact** (our `Message Handler`). He does his job with the request, for example, he **increments it with an incident Id, for instance,** and **dispatches** it to his boss, the next handler in line.

2. **The manager** is the last handler in the chain (the default/inner handler). He processes the request, and returns the results, in this case, the refund. The 1st contact picks it up and forwards it to you.

#### Creating our Message Handler

Let's then create our `Message Handler` that will be responsible for "incrementing" a request by adding an `access_token` to the `Authorization` header. We just need to create a class which inherits from the abstract `DelegatingHandler` class. Finally, we need to override the `SendAsync` and provide our logic.

```csharp
public class ProtectedApiBearerTokenHandler : DelegatingHandler
{
    private readonly IIdentityServerClient _identityServerClient;

    public ProtectedApiBearerTokenHandler(
        IIdentityServerClient identityServerClient)
    {
        _identityServerClient = identityServerClient 
            ?? throw new ArgumentNullException(nameof(identityServerClient));
    }

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, 
        CancellationToken cancellationToken)
    {
        // request the access token
        var accessToken = await _identityServerClient.RequestClientCredentialsTokenAsync();

        // set the bearer token to the outgoing request
        request.SetBearerToken(accessToken);

        // Proceed calling the inner handler, that will actually send the request
        // to our protected api
        return await base.SendAsync(request, cancellationToken);
    }
}
```

The key point in our handler is everything that happens **before** calling the next handler in line (where we do `base.SendAsync`). In our case, we are using the `IIdentityServerClient` we created before to request an `access_token`. With the token in hand, we add it to the `Authorization` header of the request. At this point, our "handler's logic" is done.  The last thing we need to do is to make sure we call the next handler in line. In our case, it will be the "inner" handler.

The inner handler will then call our Protected API. The response will "bubble" back first to the inner handler, then to our `ProtectedApiBearerTokenHandler` and finally back to us. Using the analogy from before, our handler is the "1st contact" from the internet provider company.

#### Registering and using our `ProtectedApiBearerTokenHandler`

Now that we have our handler, we need to first register it in the DI container and change our code to use it. Let's first refactor our `ProtectedApiClient` from before since we don't need to get tokens anymore. Our Handler will take care of it :)

```csharp
public class ProtectedApiClient : IProtectedApiClient
{
    private readonly HttpClient _httpClient;

    public ProtectedApiClient(HttpClient httpClient)
    {
        _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
    }

    public async Task<string> GetProtectedResources()
    {
        // No more getting access_tokens code!

        var response = await _httpClient.GetAsync("/api/protected");
        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine(response.StatusCode);
            throw new Exception("Failed to get protected resources.");
        }
        return await response.Content.ReadAsStringAsync();
    }
}
```

As you can see, we cleaned our `ProtectedApiClient` from the dependency on `IIdentityServerClient`. We just use the `HttpClient` injected as if it was an "unauthenticated" request. Next, let's register both the `ProtectedApiClient` and the `ProtectedApiBearerTokenHandler` in the DI container (inside `ConfigureServices`).

```csharp
// previous code omitted for brevity

// The DelegatingHandler has to be registered as a Transient Service
services.AddTransient<ProtectedApiBearerTokenHandler>();

// Register our ProtectedApi client with a DelegatingHandler
// that knows how to obtain an access_token
services.AddHttpClient<IProtectedApiClient, ProtectedApiClient>(client =>
{
    client.BaseAddress = new Uri("http://localhost:5002");
    client.DefaultRequestHeaders.Add("Accept", "application/json");
}).AddHttpMessageHandler<ProtectedApiBearerTokenHandler>();
```


### Final attempt - Using the `ProtectedApiClient` in our controller

With both our typed client and message handler registered it's time to refactor our controller! We'll add another endpoint `version3` and get a dependency on our `IProtectedApiClient`. Wait for it...

```csharp
[Route("api/[controller]")]
[ApiController]
public class ConsumerController : ControllerBase
{
    private readonly IProtectedApiClient _protectedApiClient;

    public ConsumerController(
        IProtectedApiClient protectedApiClient)
    {
        _protectedApiClient = protectedApiClient 
        ?? throw new ArgumentNullException(nameof(protectedApiClient));
    }

    //Uses the typed HttpClient that implicitly gets the access_token from IdentityServer
    [HttpGet("version3")]
    public async Task<IActionResult> GetVersionFour()
    {
        var result = await _protectedApiClient.GetProtectedResources();
        return Ok(result);
    }
}
```

Whoa. What an improvement, huh? We went from **48** lines of code on `version1` to **only 2** lines on `version3`. We are not creating `HttpClient`s anymore and we have nice interfaces that behave like "client" libraries to our external services. In fact, you could even turn these typed clients into a NuGet package that can be distributed let's say, between departments within your company.

## Final thoughts

I hope I helped you understand all the benefits the `HttpClientFactory` and its fellow companions can bring to your application. I myself learned a lot while actually coding this in a real app, and then trimming it down so I could write this post. 

One thing I want to share is: The `ProtectedApiBearerTokenHandler` I demonstrated here works but it's not optimal for production usage. I didn't touch on subjects like caching the access tokens for instance, but it's something you should really think about it in your application, and with that also comes thread safety and so on.

I mentioned a couple of times during the post about the `IdentityModel` NuGet package from the Identity Server "eco-system". The `IdentityModel` package also offers a `MessageHandler` that does the same thing I showed you here (handling access tokens). If you want a solid version to use in your apps, I strongly recommend checking it out: [RefreshTokenDelegatingHandler.cs](https://github.com/IdentityModel/IdentityModel2/blob/master/src/Client/RefreshTokenDelegatingHandler.cs)

## Links and references

1. https://docs.microsoft.com/en-us/aspnet/web-api/overview/advanced/http-message-handlers
2. https://www.stevejgordon.co.uk/introduction-to-httpclientfactory-aspnetcore
3. https://www.stevejgordon.co.uk/httpclient-creation-and-disposal-internals-should-i-dispose-of-httpclient
4. https://github.com/IdentityModel/IdentityModel2
5. https://odetocode.com/blogs/scott/archive/2013/04/04/webapi-tip-7-beautiful-message-handlers.aspx


### Credits:
Photo on [Visual Hunt](https://visualhunt.com/photo4/11756/barbed-wire-on-green-background/)

