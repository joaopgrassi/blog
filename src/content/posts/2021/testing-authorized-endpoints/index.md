---
# recommended 70 chars
title: "Adding integration tests for permission-protected API endpoints in ASP.NET Core"
# recommended 156 chars
description: "In this post, I'll show you how to add integration tests for API endpoints protected with permissions."

date: 2021-05-12T20:21:00+00:00
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
- src: 'request_authorization_dark.png'

---

This is the forth post in the [Authorization in ASP.NET Core](/series/authorization-in-asp.net-core) series.

- [Part 1: Using a middleware to build a permission-based identity in ASP.NET Core](/posts/2021/asp-net-core-permission-based-authorization-middleware)

- [Part 2: Deep dive into policy-based authorization in ASP.NET Core](/posts/2021/asp-net-core-deep-dive-policy-based-authorization)

- [Part 3: Protecting your API endpoints with dynamic policies in ASP.NET Core](/posts/2021/asp-net-core-protecting-api-endpoints-with-dynamic-policies)

- [Part 4: Adding integration tests for permission-protected API endpoints in ASP.NET Core (this post)](/posts/2021/asp-net-core-testing-permission-protected-api-endpoints)

In the previous post I demonstrated an approach to add authorization to our API endpoints. They are now fully protected with permissions.

We are almost there, but there is something important missing: **Tests**. 

In this post, I'll show you how we can add integration tests to our API endpoints. More specifically, I'll be focusing on how we can "mock" an authenticated user and their set of permissions so we can test all different scenarios we might need. Let's start!

## TL;DR

In this post, I demonstrated how to add integration tests for the API we have been working on. I showed how to mock an authenticated user via a custom `AuthenticationHandler` and how to modify it with different permissions for each test in order to ensure all scenarios are working.

Check the code on [GitHub](https://github.com/joaopgrassi/authz-custom-middleware/tree/main/tests/API.Tests).

## What we'll be testing

In the last post, I demonstrated that by extending the authorization framework in ASP.NET Core, we achieved a very granular level of authorization for our API endpoints. Here is a refresher:

```csharp
[PermissionAuthorize(PermissionOperator.And, Permissions.Update, Permissions.Read)]
[HttpPut]
public IActionResult Update()
{
    return Ok("It's good to change things sometimes!");
}
```

It's all nice, but without tests, we are a bit in the dark:

- Is it protected? What happens if I call it without having the required permissions?

- How can I ensure that it's clear when an existing endpoint changes its required permissions?

These are all valid questions (and many others) right? Let's see how we can address them.

## It all starts with the logged-in user

The way we achieved this authorization is by implementing a custom `AuthorizationHandler`. In the last post, we created our own (among other things), which internally inspects if the logged-in `User` has the necessary claims. Here is one part of it:

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
                // Here we are looking at the logged-in user's claims.
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
To add integration tests for the endpoint, we somehow need to have an *authenticated user* (`Context.User`) present.

If you have been following this series you know that our API has JWT Bearer token authentication configured (`services.AddAuthentication(..).AddJwtBearer(..)`).

By doing this we will be ultimately registering the `JwtBearerHandler`, which is an `AuthenticationHandler`. This handler is responsible for many things, but the important part for us now is: It creates the `ClaimsPrincipal` (`Context.User`).

When you send a request to the API passing the JWT token in the header, this handler will be invoked as part of the pipeline and the `HttpContext` will have the `User` property populated when the token is valid.

You might wonder why I'm talking about all this. What does this have to do with testing? 

During our integration tests, we want to test the **whole thing**. That includes not only our controller but also our PermissionMiddleware and all the types we created in the last post that deals with the authorization part. With a single test, we can test all the moving parts that we have been working on so far. Cool, huh?!

So, how can we make the integration tests work now that they require an authenticated user with permissions? We can't just request JWT tokens for each test. That would be very impractical. So what *can* we do?

## A custom authentication handler

Let's think about this together: We understand what the `JwtBearerHandler` does. We also understand we need a `Context.User`. Couldn't we then create our own AuthenticationHandler and take full control of it? As matter of fact, we can!

In a nutshell, to authenticate a request we need just a handful of things:

1. `ClaimsPrincipal` - our user with whatever claims we want/need

2. `AuthenticationTicket` - the "ticket" containing our principal and which scheme it's for

3. `AuthenticationResult` - the result of authenticating the request with the ticket

Here is our custom handler:

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
        // we'll see how this work later, don't worry
        _mockAuthUser = mockAuthUser;
    }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (_mockAuthUser.Claims.Count == 0)
            return Task.FromResult(AuthenticateResult.Fail("Mock auth user not configured."));

        // 2. Create the principal and the ticket
        var identity = new ClaimsIdentity(_mockAuthUser.Claims, AuthConstants.Scheme);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, AuthConstants.Scheme);

        // 3. Authenticate the request
        var result = AuthenticateResult.Success(ticket);
        return Task.FromResult(result);
    }
}
```

We start by creating a new class inheriting from the abstract `AuthenticationHandler` one. Handlers are DI enabled, and the base class requires all those params. To make it short, focus on the `mockAuthUser` param injected. That is our User! 

The `HandleAuthenticateAsync` is invoked by the framework when a request is trying to access an authorized endpoint. It will simply use the injected user and do the steps I mentioned above to authorize the request. That's pretty much it for the handler. 

Next, we'll be focusing on how to prepare the integration tests to use it.

## Registering our test authentication handler

Next, we must register our handler into DI. An extension method comes in handy:

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
Now we need to glue everything together for our tests.

## Extending our API via `WebApplicationFactory`

> The focus of this post is not how to set up integration tests. If you are not familiar with it, [check the official docs](https://docs.microsoft.com/en-us/aspnet/core/test/integration-tests?view=aspnetcore-5.0), or also my series of posts about it: [Integration tests in ASP.NET Core](https://blog.joaograssi.com/series/integration-tests-in-asp.net-core/)


These are the steps we need now:

1. Add our custom authentication handler to the api during tests (we can have multiple. The`JWTBearer` will still be there)

2. Have a way to register our mock authenticated user into DI (remember our handler needs it)

Here is how the relevant part of the `ConfigureWebHost` method looks like:

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

We register our custom handler using the extension method we just created. Then, we register the `_user` field as a scoped instance into DI.

The idea of registering a user into DI is that we can later override it with another instance during the tests. We'll see how this works next.

> You can check the complete code of the `WebApplicationFactory` on [GitHub](https://github.com/joaopgrassi/authz-custom-middleware/blob/main/tests/API.Tests/ApiApplicationFactory.cs).


## Adding an integration test

Now we have everything to write our test! Let's try this:

- **Given** an endpoint protected with the `Read` **AND** `Update` permissions :lock:
- **And** a user that does not have the `Update` permission tries to access it :smirk:
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

        // Create a user with the Read and Create permissions in our db
        var user = await CreateTestUser(Permissions.Read, Permissions.Create);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            // register this user in DI (will override the initial one)
            builder.ConfigureTestServices(services => services.AddScoped(_ => user));
        }).CreateClient();
        
        // Act
        var response = await client.PutAsync("products", new StringContent(string.Empty));
        
        // Assert
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
```

And it passes!

> The `CreateTestUser` method inserts a new user with the specified permissions (`Update`,`Create`) in the database. In the first post of the series, we created a [middleware that loads the permissions](https://github.com/joaopgrassi/authz-custom-middleware/blob/57adf66c0932e9fdb2fad742e24f94ffdb74d44e/src/API/Authorization/PermissionsMiddleware.cs#L39) from the database based on the user `sub` claim. The middleware then uses the permissions found to augment the ClaimsPrincipal.

The test is simple but it gives us so much value. Now we are sure that:

1. The middleware works - The user's permissions are loaded from the db and added to the `ClaimsPrincipal`

2. The `PermissionHandler` correctly checks the endpoint's permissions against the user's `Claims`

3. The endpoint is in fact protected


Putting all together in a diagram, the "flow" looks more or less like this:

{{< img "*request_authorization*" "Flow of testing a protected endpoint" "*request_authorization_dark*">}}

That's it. Now we can add all sorts of tests and combinations as we see fit.


## Conclusion

In the previous post of the series, we added authorization to our API endpoints, but we didn't know it was working as we expected. We were missing a way to verify it.

In this post, I showed you how to solved that by adding integration tests. The tests gave us the answer that our endpoints are indeed protected and that the permission checks work.

We saw how to mock an authenticated user for our tests by implementing a custom `AuthenticationHandler`. We then manipulated this user to test all different permission scenarios.

All the questions from the beginning were answered:

**Is it protected? What happens if I call it without having the required permissions?**
*The API returns a 403 - Forbidden. The endpoint is not reached.*

**How can I ensure that it's clear when an existing endpoint changes its required permissions?**
*If we have tests for it when someone changes the endpoint's permissions the tests will fail (with some caveats).*

As usual, all the code is on [GitHub](https://github.com/joaopgrassi/authz-custom-middleware/tree/main/tests/API.Tests). The relevant parts are inside`API.Tests`.

Thanks for reading and I hope this was useful to you. Share with your .NET friends :wink:

[Photo by Abdullah Aydin](https://unsplash.com/@aydinabdullah?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText) on [Unsplash](https://unsplash.com/photos/X2MkCH617-o)
  