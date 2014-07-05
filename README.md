Publish with reactive dependencies
==================================

Adding this package to your [Meteor](http://www.meteor.com/) application augments
[Meteor.publish](http://docs.meteor.com/#meteor_publish) handler object with method
`related` which allows you to define publish endpoints with reactive dependencies on
additional queries. It allows easy wrapping of existing publish functions without any
change needed. You can use publish functions which return query cursors, or which
uses publish `added`/`changed`/`removed` API.

This is useful in all situations where you want to publish documents which have a
query based on data from some other document and you want that everything behaves
reactively, if any of those documents change, published documents should change as
well. Examples are any queries which limit published based documents on a list
of IDs in another document. Or a permission system where you want to limit published
documents based on flags and other properties of currently logged-in user.

Server side only.

Installation
------------

```
mrt add related
```

`this.related`
--------------

Along with existing properties and methods, `this` inside `Meteor.publish` callback now
has `related` method available. Method accepts:

 * a callback – a new publish callback which will get as arguments results of your queries
 * one or more query cursors which should each return at most one document at any given moment;
 documents returned from query cursors will then be passed to the callback reactively, every
 time any of them changes callback will be rerun

Example
-------

Let's say that you have a list of blog posts user is following as `follows` field in Meteor's
`users` documents. You want to create a publish endpoint which will publish only those blog posts
which current user follows. But if `follows` field changes, published blog posts should also
change (or if published blog posts themselves change, changes should be pushed to the client).

```
Meteor.publish('followed-blog-posts', function () {
  if (!this.userId) return;

  this.related(function (user) {
    return Posts.find({_id: {$in: user.follows}});
  },
    Meteor.users.find(this.userId, {fields: {follows: 1}})
  );
});
```

Every time `follows` field of currently logged-in user changes, related publish callback is
rerun with new `user` document as an argument (as returned from `Meteor.users.find` query).
Callback should do anything a normal publish callback should: or call `added`/`changed`/`removed`,
or simply return a query to publish like in our example.

Documents are tracked between reruns and are not republished if they remain the same between
reruns.

Known limitations
-----------------

Currently each of related queries is expected to return at most one document at all times.
In theory returning multiple documents could be supported, but this means that related publish
callback would be rerun at any change of any of those multiple documents. This is probably not
a very efficient approach.

Nested calls to `related` should probably work, but were not yet tested.

Related projects
----------------

There are few other similar projects trying to address a similar feature. We needed something
production grade, with tests, and simple code base built upon existing Meteor features
instead of trying to replace them. Most of our code just wraps existing Meteor code into the
reactive loop, and allowing existing publish functions to be reused without any change needed,
you can return queries or you can use `added`/`changed`/`removed`, all this is supported. Just
instead of having static arguments to your publish function, publish function is rerun when any
of arguments changes. Its API is thus simple and intuitive.

* [meteor-reactive-publish](https://github.com/Diggsey/meteor-reactive-publish) – uses API based on server-side dependency
tracking, but no tests and no support for `added`/`changed`/`removed`
* [meteor-publish-with-relations](https://github.com/svasva/meteor-publish-with-relations) – complicated custom API not
allowing to reuse existing publish functions, which means no support for `added`/`changed`/`removed` as well
* [meteor-smart-publish](https://github.com/yeputons/meteor-smart-publish) – complicated way of defining dependencies
and works only with query cursors and not custom `added`/`changed`/`removed` functions
