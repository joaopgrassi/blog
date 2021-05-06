---
# recommended 70 chars
title: "Adding integration tests for permission-protected API endpoints in ASP.NET Core"
# recommended 156 chars
description: "In this post I'll show you how to add integration tests for API endpoints that we protected with permissions in the last post."

date: 2021-03-31T21:21:00+00:00
tags: ["asp.net-core", "authorization", "security", "permission-based-authorization", "policies", integration-tests]
author: "Joao Grassi"
showToc: true
TocOpen: false
draft: false
hidemeta: true
comments: false
slug: "asp-net-core-testing-permission-protected-api-endpoints"
type: posts
series: ['Authorization in ASP.NET Core']

cover:
    image: "testing-endpoints-cover.png"
    relative: true
    alt: "Padlock on a wooden door"

resources:
- src: 'request_authorization.png'

---

This is the forth post in the [Authorization in ASP.NET Core](/series/authorization-in-asp.net-core) series.

- [Part 1: Using a middleware to build a permission-based identity in ASP.NET Core](/posts/2021/asp-net-core-permission-based-authorization-middleware)

- [Part 2: Deep dive into policy-based authorization in ASP.NET Core](/posts/2021/asp-net-core-deep-dive-policy-based-authorization)

- [Part 3: Protecting your API endpoints with dynamic policies in ASP.NET Core](/posts/2021/asp-net-core-protecting-api-endpoints-with-dynamic-policies)

- [Part 4: Adding integration tests for permission-protected API endpoints in ASP.NET Core (this post)](/posts/2021/asp-net-core-protecting-api-endpoints-with-dynamic-policies)

In this post, I'll show you how we can add integration tests to our API endpoints, that are now using our custom `PermissionAuthorize` attribute. The focus will be more on how we can "mock" an authenticated user and their set of permissions. Let's start!


## TL;DR

In this post, I demonstrated how to add integration tests for the API we have been working on. I showed how to mock an authenticated user via a custom `AuthenticationHandler` and how to modify it with different permissions for each test in order to ensure all scenarios are working.

Check the code on [GitHub](https://github.com/joaopgrassi/authz-custom-middleware/tree/main/tests/API.Tests).

## What we'll be testing

In the last post, I demonstraded that by extending the authorization framework in ASP.NET Core, we were able to achieve a very granular level of authorization for our API endpoints. A quick recap of what we achieved was:

```csharp
[PermissionAuthorize(PermissionOperator.And, Permissions.Update, Permissions.Read)]
[HttpPut]
public IActionResult Update()
{
    return Ok("It's good to change things sometimes!");
}
```

It's all nice, but without tests we are a bit in the dark:

- Is it really protected? What happens if I call it without having the required permissions?

- Does it work if it's an `OR` and I have one of the permissions listed?

- How can I ensure that it's clear when an existing endpoint changes its required permissions?

These are all valid questions (and many others), right? Let's see how we can address them.

## It all starts with the logged-in user

The way we achieved this authorization is by implementing a custom `AuthorizationHandler`. In the last post we created our own (among other things), which internally inspects if the logged in `User` has the necessary claims. Here is one part of it to refresh things:

```csharp
public class PermissionHandler : AuthorizationHandler<PermissionRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context, PermissionRequirement requirement)
    {
        if (requirement.PermissionOperator == PermissionOperator.And)
        {
            foreach (var permission in requirement.Permissions)
            {
                // Here we are looking at the logged-in user claims.
                if (!context.User.HasClaim(PermissionRequirement.ClaimType, permission))
                {
                    context.Fail();
                    return Task.CompletedTask;
                }
            }
            context.Succeed(requirement);
            return Task.CompletedTask;
        }
// omitted for brevity
```
In order to add integration tests for the endpoint, we somehow need to have an authenticated user when making the requests.


## A custom authentication handler

In a nutshel, in order to authenticate a request we need just a handful of things:

1. `ClaimsPrincipal` - our user with whatever claims we want/need

2. `AuthenticationTicket` - the "ticket" containing our principal and the which scheme it's for

3. `AuthenticationResult` - the result of authenticating the request with the ticket

The question is: Where do we do this work? In an `AuthenticationHandler`.

When we use: `services.AddAuthentication().AddJwtBearer(..)` we are registering the `JwtBearerHandler` which will, ultimately, do the 3 steps above. 

That means for our tests we can just do the same! We can create our `TestAuthHandler` and authenticate the request in whatever ways we want.

```csharp
// usings omitted for brevity. Don't worry the full code is on GitHub :)

public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    private readonly MockAuthUser _mockAuthUser;

    public TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder,
        ISystemClock clock,
        MockAuthUser mockAuthUser)
        : base(options, logger, encoder, clock)
    {
        // 1. We get a "mock" user instance here via DI.
        _mockAuthUser = mockAuthUser;
    }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (_mockAuthUser.Claims.Count == 0)
            return Task.FromResult(AuthenticateResult.Fail("Mock auth user not configured."));

        // 2. Create the identity and the ticket
        var identity = new ClaimsIdentity(_mockAuthUser.Claims, AuthConstants.Scheme);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, AuthConstants.Scheme);

        // 3. Authenticate the request
        var result = AuthenticateResult.Success(ticket);
        return Task.FromResult(result);
    }
}
```

We start by creating a new class inheriting from the abstract `AuthenticationHandler` one. Handlers are DI enabled, and the base class requires all those params. To make it short, focus on the `mockAuthUser` param being injected. That is our User! 

The `HandleAuthenticateAsync` is invoked by the framework when a request is trying to access an authorized endpoint. It will simple use the injected user and do the steps I mentioned above to authorize the request. That's pretty much it for the handler. 

## Registering our test authentication handler

Now that we have our handler, we need to register it, so the framework is aware of it. A quick extension method makes things easy:

```csharp
public static class AuthServiceCollectionExtensions
{
    public static AuthenticationBuilder AddTestAuthentication(
        this IServiceCollection services)
    {
        services.AddAuthorization(options =>
        {
            // AuthConstants.Scheme is just a scheme we define. I called it "TestAuth"
            options.DefaultPolicy = new AuthorizationPolicyBuilder(AuthConstants.Scheme)
                .RequireAuthenticatedUser()
                .Build();
        });

        // Register our custom authentication handler
        return services.AddAuthentication(AuthConstants.Scheme)
            .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                AuthConstants.Scheme, options => { });
    }
}
```
Now we just need to glue everything together for our tests. Let's see how next.


## Extending our API via `WebApplicationFactory`

> The focus of this post is not how to setup integration tests. If you are not familiar with it, [check the official docs](https://docs.microsoft.com/en-us/aspnet/core/test/integration-tests?view=aspnetcore-5.0), or also my series of posts about it: [Integration tests in ASP.NET Core](https://blog.joaograssi.com/series/integration-tests-in-asp.net-core/)


Now that we have our handler, we need to achieve these things:

1. Add our custom authentication handler to the app (we can have multiple, so it's OK to still have the `JWTBearer` one)

2. Have a way to register our mock authenticated user into DI, so the handler can get it


This is how our `ConfigureWebHost` method looks like after the changes:

```csharp

// Default logged in user for all requests - can be overwritten in individual tests
private readonly MockAuthUser _user = new MockAuthUser(
    new Claim("sub", Guid.NewGuid().ToString()),
    new Claim("email", "default-user@xyz.com"));

protected override void ConfigureWebHost(IWebHostBuilder builder)
{
    builder.UseEnvironment("Test");
    builder.ConfigureServices(services => 
        {
            // Add our custom handler
            services.AddTestAuthentication();
            
            // Register a default user, so all requests have it by default
            services.AddScoped(_ => _user);       
        })
}

public class MockAuthUser
{
    public List<Claim> Claims { get; private set; } = new();

    public MockAuthUser(params Claim[] claims)
        => Claims = claims.ToList();
}

```

There's more stuff in `ConfigureWebHost`, but the only relevant part for us here are those. We register our handler and our default user instance. 

The idea to register the instance of the user via DI, is that later in a test we can just register another instance which will override this one. This is how we can test different cases, like a user having vs not having a permission.

## Adding an integration test

Now we have everything to write our test! Let's try this:

- **Given** an endpoint protected with the `Read` permission :lock:
- **And** a user that does not have a `Read` permission tries to access it :smirk:
- **Then** the API returns a `403 - Forbidden` response code :no_entry:


```csharp
public class ProductControllerTests : IClassFixture<ApiApplicationFactory>
{
    private readonly ApiApplicationFactory _factory;

    public ProductControllerTests(ApiApplicationFactory factory)
    {
        _factory = factory;
    }
    
    [Fact]
    public async Task Put_RequiresReadAndUpdate_UserHasOnlyReadPermission_ShouldReturn403Forbidden()
    {
        // Arrange
        var user = await CreateTestUser(Permissions.Read, Permissions.Create);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureTestServices(services => services.AddScoped(_ => user));
        }).CreateClient();
        
        // Act
        var response = await client.PutAsync("products", new StringContent(string.Empty));
        
        // Assert
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
```

And it passes!

> The `CreateTestUser` method simply adds a new user with the specified permissions (`Update`,`Create`) in the database. If you remember, in the first post of this series we created a [middleware that loads the permissions](https://github.com/joaopgrassi/authz-custom-middleware/blob/57adf66c0932e9fdb2fad742e24f94ffdb74d44e/src/API/Authorization/PermissionsMiddleware.cs#L39) from the database based on the user `sub` claim.

The test is simple but it gives us so much value. Now we know that:

1. The middleware works - The user permissions are loaded from the db and added to the `ClaimsPrincipal`

2. The `PermissionHandler` has the requirement and it correctly checks it against the User `Claims`

3. The endpoint is in fact protected


Putting all together in a diagram, the "flow" looks more or less like this:

{{< img "*request_authorization*" "Flow of testing a protected endpoint" >}}


## Conclusion

In the last post of the series we added authorization to our API endpoints, but we really didn't know it was working as we expected. 

In this post I showed you how we can add integration tests for our API. More specifically, I focused on what we needed to do in order to have an authenticated user during the tests and how we could manipulate this user to test different permissions scenarios.

This was all done by implementing a custom `AuthenticationHandler` and overriding the services of the API inside our `ApiApplicationFactory`

We answered all the questions at the beginning of the posts

- Is it really protected? What happens if I call it without having the required permissions?
> The API returns a 403 - Forbidden. The endpoint is not even reached.

- Does it work if it's an `OR` and I have one of the permissions listed?
> Yes :) both cases work

- How can I ensure that it's clear when an existing endpoint changes its required permissions?
> If we have tests for it, then when someone changes a permission in a endpoint the tests will fail (with some caviates)

As usual, I have all this on [GitHub](https://github.com/joaopgrassi/authz-custom-middleware/tree/main/tests/API.Tests). For this post, the interesting parts are inside `API.Tests`. Check the `MockAuth` folder for our custom authentication handler.

Thanks for reading and I hope this was useful to you. Share with your .NET friends :wink:

[Photo by Abdullah Aydin](https://unsplash.com/@aydinabdullah?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/photos/X2MkCH617-o)
  