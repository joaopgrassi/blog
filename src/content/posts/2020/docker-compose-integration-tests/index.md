---
title: "Using docker-compose for your ASP.NET + EF Core integration tests"
description: "In this post, we will be looking at how can you run the integration tests of an ASP.NET + EF Core app against a \"full\" SQL Server instead of using the in-memory database providers."
date: 2020-08-13T21:21:00+00:00
tags: ["asp.net-core", ".net-core", "integration-tests", "entity-framework-core", "docker"]
author: "Joao Grassi"
showToc: true
TocOpen: false
draft: false
hidemeta: true
comments: false
url: using-docker-compose-for-your-asp-net-ef-core-integration-tests
type: posts
series: ['Integration tests in ASP.NET Core']

# images:
# - using-docker-compose-for-your-asp-net-ef-core-integration-tests/using-docker-compose-for-your-asp-net-ef-core-integration-tests.jpg

resources:
- src: 'twitter_dbcontext_pooling.png'

cover:
    image: "using-docker-compose-for-your-asp-net-ef-core-integration-tests.jpg"
    relative: true
    alt: "View from above of containers in a port"

---

This is the second post in the [Integration tests in ASP.NET Core](/series/integration-tests-in-asp.net-core) series.

- [Part 1: Limitations of the EF Core in-memory database providers](/limitations-ef-core-in-memory-database-providers)

- [Part 2: Using docker-compose for your ASP.NET + EF Core integration tests (this post)](/using-docker-compose-for-your-asp-net-ef-core-integration-tests)

- [Part 3: ASP.NET Core integration tests with docker-compose on Azure Pipelines](/asp-net-core-integration-tests-with-docker-compose-azure-pipelines)

In this post, we will be looking at how you can run the integration tests of an ASP.NET + EF Core app against a "full" SQL Server instead of using the in-memory database providers. We'll be looking at this from a local development perspective and expand on it later in the next posts.


## TL;DR

Used [docker-compose](https://docs.docker.com/compose/),  [xunit Collection Fixtures](https://xunit.net/docs/shared-context.html) and [WebApplicationFactory](https://docs.microsoft.com/en-us/aspnet/core/test/integration-tests?view=aspnetcore-3.1#customize-webapplicationfactory) in order to connect to SQL Server running on Docker and create/migrate/drop a new database for each test run. 

If you want to skip and jump right at the code, [check the project on GitHub](https://github.com/joaopgrassi/dockercompose-azdevops)


## Alternatives to the in-memory database providers

If I'm not using the in-memory database providers, then I need to have a full SQL Server instance running on my machine? Not really. We have some options:

- SQL LocalDB
- SQL Server running on Docker

SQL LocalDB works great but.. it doesn't work on Linux and you need to install it in your Windows machine. If you use Visual Studio you probably already have it installed but with more and more people using VS Code and Rider as their main IDEs, these options don't work well.

If you don't know SQL Server is available on Linux for quite some time now. Even better, it's [available as a Docker image](https://hub.docker.com/_/microsoft-mssql-server). This is very powerful because it enables virtually anyone to have a full-fletched SQL Server running without having to install anything other than Docker.

So the answer I chose for my projects is **Docker**!

## Using `docker-compose` for your integration tests

We just need a `docker-compose.yml` file at the root of our repo which starts a SQL Server container for us. If you don't know what docker-compose is, you can take a look at the [official documentation](https://docs.docker.com/compose/). In very crude terms it's just a way to tell Docker: run all these things for me and make them work together!

An example `docker-compose.yml` file that starts a SQL Server instance looks like this:

```yaml{.line-numbers}
version: "3.7"

networks:
  blogapp-network:
  
services:
  blogapp-sqlserver:
    image: "mcr.microsoft.com/mssql/server"
    ports:
      - "1433:1433"
    environment:
        SA_PASSWORD: "2@LaiNw)PDvs^t>L!Ybt]6H^%h3U>M"
        ACCEPT_EULA: "Y"
    networks:
      - blogapp-network
```

I'll skip the details on this file since it's too much for a single post, but the important parts are the `image` which tells what we want, in this case, SQL Server. The `port` which is mapping/exposing the port **1433** of the container to the host (our machines) and the password for the `sa` user.

When you are ready, just execute `docker-compose up` at the root of your repo using your favorite shell and you are good to go! You have a full SQL Server at your disposal. Next, we'll see then how to configure your code to use it.


## ASP.NET Core integration tests against a real SQL Server

For this part, I'm going to use a sample app based on the Blog entities that are in the official EF Core docs. It's an ASP.NET Core API that has a controller to expose some CRUD operations around a `Blog` entity. All the code is available on [GitHub](https://github.com/joaopgrassi/dockercompose-azdevops). 

For brevity I'll skip some of the details about integration tests otherwise this will get long. If you are not familiar with it you can get up to speed by reading this: [Integration tests in ASP.NET Core](https://docs.microsoft.com/en-us/aspnet/core/test/integration-tests?view=aspnetcore-3.1)

The way things come together in a test project is by creating a class deriving from `WebApplicationFactory`. In this class, we have the possibility to alter our real app in any way we want. For example, in the link above they show you how to switch the registered DbContext with your "real" connection string to an in-memory one during the tests. 

We'll be using our container instead of the in-memory providers as you guessed by now. But first, we need to consider some points.


### Understanding the lifetime of things during the integration tests

Testing code that uses EF Core means that we have to do the following **at least once during a test run**

- Run the migrations in order to create the database
- Maybe run some seed method
- Drop the database when done testing

This is **very fast** when using the in-memory providers but when using a real SQL Server it's not so fast anymore. It's still just within a second or so but you need to think better now **when and how many times** you want to do it. Because this can drastically impact the speed of your tests.

Different testing frameworks offer different ways to share data across a test run. `xunit` offers 3 ways: 

- **Constructor and Dispose** (shared setup/cleanup code without sharing object instances)
- **Class Fixtures** (shared object instance across tests in a single class)
- **Collection Fixtures** (shared object instances across multiple test classes)

> Since `xunit` is the [most used test framework](https://nugettrends.com/packages?months=24&ids=xunit&ids=NUnit&ids=MSTest.TestFramework) in .NET, that's what I'll be using for the rest of the post.

We can use a `Collection Fixture` in order to create the database once and use the same for all integration tests. Once all tests are finished, we can drop the database.

You have to understand though when writing your tests this way that **you cannot rely on the state of the database** because you don't know which test executed before and what data it might have modified. For that reason, I always treat each test as if the database was empty and I *always insert the data I want to assert first*.

Let's see how to do this next.


### Creating our DB Collection Fixture


```csharp
using BlogApp.Data;
using Microsoft.EntityFrameworkCore;
using System;
using Xunit;

namespace BlogApp.Api.Tests
{
    public class DbFixture : IDisposable
    {
        private readonly BlogDbContext _dbContext;
        public readonly string BlogDbName = $"Blog-{Guid.NewGuid()}";
        public readonly string ConnString;
        
        private bool _disposed;

        public DbFixture()
        {
            ConnString = $"Server=localhost,1433;Database={BlogDbName};User=sa;Password=2@LaiNw)PDvs^t>L!Ybt]6H^%h3U>M";

            var builder = new DbContextOptionsBuilder<BlogDbContext>();

            builder.UseSqlServer(ConnString);
            _dbContext = new BlogDbContext(builder.Options);

            _dbContext.Database.Migrate();
        }

        public void Dispose()
        {
            Dispose(disposing: true);
            GC.SuppressFinalize(this);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (!_disposed)
            {
                if (disposing)
                {
                    // remove the temp db from the server once all tests are done
                    _dbContext.Database.EnsureDeleted();
                }

                _disposed = true;
            }
        }
    }

    [CollectionDefinition("Database")]
    public class DatabaseCollection : ICollectionFixture<DbFixture>
    {
        // This class has no code, and is never created. Its purpose is simply
        // to be the place to apply [CollectionDefinition] and all the
        // ICollectionFixture<> interfaces.
    }
}


```

The constructor is the important part of this class:

- Initializes a connection string pointing to our SQL Server **running on Docker** (localhost, 1433)
- Uses a `Guid` in the database name in order to create a random one on the server every time
- Creates a `DbContext` instance and calls `Migrate` in order to create the database (applying the migrations)

The fixture also implements `IDisposable` in order to drop the database at the end of each test run.

Now we need to create the `WebApplicationFactory` and use this Fixture there.

### Creating our WebApplicationFactory

The `WebApplicationFactory` is where we can tell ASP.NET Core: When the app requests an instance of a `DbContext` via DI, use this one. This is how it looks like:

### Update - Aug 13 2020

In the original post, I showed you how to use the Docker connection string by removing the original DbContext registration inside the `WebApplicationFactory`. [Alexey](https://twitter.com/Tyrrrz) pointed out that there are some good benefits of **not** doing that. A big one that I was not aware, is when using [DbContext pooling](https://docs.microsoft.com/en-us/ef/core/what-is-new/ef-core-2.0#dbcontext-pooling). In that case, you might have custom configuration and by removing the original registration you are losing that, which defeats the purpose of integration tests.

{{< img "*twitter_dbcontext_pooling*" "Alexey's suggestion on not removing the original DbContext registration" >}}

One easy solution is instead of removing the original `DbContext` registration, we just add an `In-memory` configuration provider with our integration test connection string. That will override the one in your `appsettings.json` during the tests. I've updated the code snippet below to reflect that along with the project on GitHub. Thanks, Alexey!

```csharp{.line-numbers}
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using System.Collections.Generic;
using Xunit;

namespace BlogApp.Api.Tests
{
    [Collection("Database")]
    public class BlogWebApplicationFactory : WebApplicationFactory<Startup>
    {
        private readonly DbFixture _dbFixture;

        public BlogWebApplicationFactory(DbFixture dbFixture)
            => _dbFixture = dbFixture;

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Test");
            
            // UPDATE: No need to remove the original DbContext.
            // To use our Docker db, we can just provide an in-memory config provider.		
            // The original code is just here for reference.
            
            //builder.ConfigureServices(services =>
            //{
            //    // Remove the app's BlogDbContext registration.
            //    var descriptor = services.SingleOrDefault(
            //        d => d.ServiceType ==
            //            typeof(DbContextOptions<BlogDbContext>));

            //    if (descriptor is object)
            //        services.Remove(descriptor);

            //    services.AddDbContext<BlogDbContext>(options =>
            //    {
            //        // uses the connection string from the fixture
            //        options.UseSqlServer(_dbFixture.ConnString);
            //    });
            //})
            builder.ConfigureAppConfiguration((context, config) =>
            {
                config.AddInMemoryCollection(new[]
                {
                    new KeyValuePair<string, string>(
                        "ConnectionStrings:BlogConnection", _dbFixture.ConnString)
                });
            });
        }
    }
}


```
Let's go through it:

1. Note the `[Collection("Database")]` attribute on the class. That tells `xunit` to inject the database fixture into this class's constructor.

2. On line 41 we add an in-memory configuration provider with our Docker connection string. When the app starts, this will override the connection string in `appsettings.<env>.json`. No need to remove the original DbContext.

We have all we need now. Let's connect all the pieces!


### Creating an integration test

This is an example of an integration test class for our Blog controller:


```csharp{.line-numbers}
using BlogApp.Api.Controllers.Models;
using BlogApp.Data.Entities;
using FluentAssertions;
using System;
using System.Net.Http;
using System.Threading.Tasks;
using Xunit;

namespace BlogApp.Api.Tests.Controllers
{
    [Collection("Database")]
    public sealed class BlogsControllerTests : IClassFixture<BlogWebApplicationFactory>
    {
        private readonly BlogWebApplicationFactory _factory;

        public BlogsControllerTests(BlogWebApplicationFactory factory)
        {
            _factory = factory;
        }

        [Fact]
        public async Task Create_ShouldCreateBlog()
        {
            // Arrange
            var createRequest = new CreateBlogRequest
            {
                Url = "https://aspnet-core-is-cool.net"
            };

            var client = _factory.CreateClient();

            // Act
            var postResponse = await client
            .PostAsync("/v1/blogs", new JsonContent<CreateBlogRequest>(createRequest));
            
            var blogCreateResponse = await postResponse.Content.ReadAsJsonAsync<Blog>();

            // Assert - by calling the Get/id and comparing the results
            var getResponse = await client
            .GetAsync($"/v1/blogs/{blogCreateResponse.Id}");
            
            var blogGetResponse =  await getResponse.Content.ReadAsJsonAsync<Blog>();

            blogGetResponse.Should().BeEquivalentTo(blogCreateResponse);
        }
    }
}
```

Again let's inspect things a bit:

1. This class also has the `[Collection]` attribute the same as the factory. We need this otherwise the factory doesn't get the Fixture injected since it's not a test on itself but rather just a normal class.

2. We use another `xunit` way of sharing data: `IClassFixture`. This will inject our `WebApplicationFactory` into the test class's constructor and the same factory is shared for all tests **in this class only**

3. On line `30` we use the factory to create the `HttpClient`

4. Next, we issue a `POST` request to the blog controller to create our blog
5. Then, we issue a `GET` request using the `Id` returned
6. Finally, we compare both values to see if they match


That's it! The integration test is succinct and easy to understand. All the inner works of creating/migrating the database and dropping it are hidden away by the Collection Fixture + WebApplicationFactory.

The only thing developers working on this project need to do before running the tests is to execute `docker-compose up` (Assuming Docker is already running).


## Summary

In this post we looked at several things so let's recap a bit:

1. Created our `docker-compose.yaml` file which contains our SQL Server container

2. Understood the lifetime of a test run in `xunit` and used a Collection Fixture to manage our database creation/migration/deletion

3. Used a in-memory configuration provider inside our `WebApplicationFactory` in order to override the connection string present in `appsettings.<env>.json` and use the one connecting to our SQL Server running on Docker.

4. Created an integration test that `POST` and `GET` a blog from our SQL Server running on Docker

This solution combines the power of Docker containers with techniques to share "things" across tests using `xunit` and `WebApplicationFactory`. 

With the approach I presented in this post, your tests now match better your production environment, thus exposing **possible bugs earlier** and giving you **more confidence** when you are ready to deploy your apps.

Coming up next, I'll show you how you can run the same tests with Docker during your CI Build in Azure DevOps. Stay tuned!

[Photo by Tom Fisk from Pexels](https://www.pexels.com/photo/aerial-photography-of-container-van-lot-3063470/)
