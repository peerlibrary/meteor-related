unless originalPublish
  originalPublish = Meteor.publish

  Meteor.publish = (name, func) ->
    originalPublish name, (args...) ->
      publish = @

      # This function wraps the logic of publishing related documents. publishFunction gets
      # as arguments documents returned from related querysets. Every time any related document
      # changes, publishFunction is rerun. The requirement is that related querysets return
      # exactly one document. publishFunction can be anything a normal publish endpoint function
      # can be, it can return querysets or can call added/changed/removed. It does not have to
      # care about unpublishing documents which are not published anymore after the rerun, or
      # care about publishing only changes to documents after the rerun.

      # TODO: Should we use try/except around the code so that if there is any exception we stop handlers?
      publish.related = (publishFunction, related...) ->
        relatedPublish = null
        ready = false

        publishDocuments = (relatedDocuments) ->
          oldRelatedPublish = relatedPublish

          relatedPublish = publish._recreate()

          # We copy overridden methods if they exist
          for own key, value of publish when key in ['added', 'changed', 'removed', 'ready', 'stop', 'error']
            relatedPublish[key] = value

          # If there are any extra fields which do not exist in recreated related publish
          # (because they were added by some other code), copy them over
          # TODO: This copies also @related, test how recursive @related works
          for own key, value of publish when key not of relatedPublish
            relatedPublish[key] = value

          relatedPublishAdded = relatedPublish.added
          relatedPublish.added = (collectionName, id, fields) ->
            stringId = @_idFilter.idStringify id
            # If document as already present in oldRelatedPublish then we just set
            # relatedPublish's _documents and call changed to send updated fields
            # (Meteor sends only a diff).
            if oldRelatedPublish?._documents[collectionName]?[stringId]
              Meteor._ensure(@_documents, collectionName)[stringId] = true
              oldFields = {}
              # If some field existed before, but does not exist anymore, we have to remove it by calling "changed"
              # with value set to "undefined". So we look into current session's state and see which fields are currently
              # known and create an object of same fields, just all values set to "undefined". We then override some fields
              # with new values. Only top-level fields matter.
              for field of @_session.getCollectionView(collectionName)?.documents?[id]?.dataByKey or {}
                oldFields[field] = undefined
              @changed collectionName, id, _.extend oldFields, fields
            else
              relatedPublishAdded.call @, collectionName, id, fields

          relatedPublish.ready = ->
            # Mark it as ready only the first time
            publish.ready() unless ready
            ready = true
            # To return nothing, so that it can be used at the end of the
            # publish function in CoffeeScript without an error
            return

          relatedPublish.stop = (relatedChange) ->
            if relatedChange
              # We only deactivate (which calls stop callbacks as well) because we
              # have manually removed only documents which are not published again.
              @_deactivate()
            else
              # We do manually what would _stopSubscription do, but without
              # subscription handling. This should be done by the parent publish.
              @_removeAllDocuments()
              @_deactivate()
              publish.stop()

          if Package['audit-argument-checks']
            relatedPublish._handler = (args...) ->
              # Related parameters are trusted
              check arg, Match.Any for arg in args
              publishFunction.apply @, args
          else
            relatedPublish._handler = publishFunction
          relatedPublish._params = relatedDocuments
          relatedPublish._runHandler()

          return unless oldRelatedPublish

          # We remove those which are not published anymore
          for collectionName in _.keys(oldRelatedPublish._documents)
            for id in _.difference _.keys(oldRelatedPublish._documents[collectionName] or {}), _.keys(relatedPublish._documents[collectionName] or {})
              oldRelatedPublish.removed collectionName, id

          oldRelatedPublish.stop true
          oldRelatedPublish = null

        currentRelatedDocuments = []
        handleRelatedDocuments = []

        relatedInitializing = related.length

        for r, i in related
          do (r, i) ->
            currentRelatedDocuments[i] = null
            handleRelatedDocuments[i] = r.observe
              added: (doc) ->
                # There should be only one document with the id at every given moment
                assert.equal currentRelatedDocuments[i], null

                currentRelatedDocuments[i] = doc
                publishDocuments currentRelatedDocuments if relatedInitializing is 0

              changed: (newDoc, oldDoc) ->
                # Document should already be added
                assert.equal currentRelatedDocuments[i]?._id, newDoc._id

                currentRelatedDocuments[i] = newDoc

                # We are checking relatedInitializing even here because it could happen that this is triggered why other related documents are still being initialized
                publishDocuments currentRelatedDocuments if relatedInitializing is 0

              removed: (oldDoc) ->
                # We cannot remove the document if we never added the document before
                assert.equal currentRelatedDocuments[i]?._id, oldDoc._id

                currentRelatedDocuments[i] = null

                # We are checking relatedInitializing even here because it could happen that this is triggered why other related documents are still being initialized
                publishDocuments currentRelatedDocuments if relatedInitializing is 0

          # We initialized this related document
          relatedInitializing--

        assert.equal relatedInitializing, 0

        # We call publishDocuments for the first time
        publishDocuments currentRelatedDocuments

        publish.onStop ->
          for handle, i in handleRelatedDocuments
            handle?.stop()
            handleRelatedDocuments[i] = null
          relatedPublish?.stop()
          relatedPublish = null

      func.apply publish, args
