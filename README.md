# Who's got dirt? JSON file API

[![Dependency Status](https://gemnasium.com/influencemapping/whos_got_dirt-json_file_api.png)](https://gemnasium.com/influencemapping/whos_got_dirt-json_file_api)
[![Code Climate](https://codeclimate.com/github/influencemapping/whos_got_dirt-json_file_api.png)](https://codeclimate.com/github/influencemapping/whos_got_dirt-json_file_api)

This server wraps remote JSON files in a simple API.

## API

`get /:url?path=path&q=query`

The `:url` parameter must be a whitelisted URL that returns a **JSON array**. The required `path` query string parameter is a [JSON Pointer](http://tools.ietf.org/html/rfc6901) that will be evaluated against each item in the **JSON array** to produce a **values list**. The required `q` query string parameter will be compared and scored against each item in this **values list** to produce a results list, which will be returned as a JSON response.

## Development

```
bundle
WHOSGOTDIRT_WHITELIST=http://quienmanda.es/entities.json bundle exec rackup
curl http://localhost:9292/http%3A%2F%2Fquienmanda.es%2Fentities.json?path=/name&q=instituto
```

## Deployment

```
heroku apps:create
heroku addons:create memcachier:dev
heroku config:set WHOSGOTDIRT_WHITELIST=http://quienmanda.es/entities.json
heroku config:set WHOSGOTDIRT_THRESHOLD=0.4
git push heroku master
```

## Notes

String comparison in other languages:

* [jellyfish](https://github.com/jamesturk/jellyfish) (Python)
* [cjellyfish](https://github.com/jamesturk/cjellyfish) (C)
* [difflib](https://docs.python.org/2/library/difflib.html) (Python)
* [nltk](http://www.nltk.org/api/nltk.metrics.html) (Python)

Copyright (c) 2015 James McKinney, released under the MIT license
