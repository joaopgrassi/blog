# My personal blog

This is the source repo of my blog at https://blog.joaograssi.com. It is built using the static site generator [Hugo](gohugo.io).


## Running with ngrok + live reload

```
$ ngrok http 1313
$ hugo server -b <ngrok-url>--appendPort=false --liveReloadPort=443 --navigateToChanged
```

# License
See LICENSE.md.
