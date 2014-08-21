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

        publishDocuments = (relatedDocuments) ->
          oldRelatedPublish = relatedPublish

          relatedPublish = publish._recreate()
          # TODO: Test how recursive @related works
          relatedPublish.related = publish.related

          relatedPublishAdded = relatedPublish.added
          relatedPublish.added = (collectionName, id, fields) ->
            stringId = @_idFilter.idStringify id
            # If document as already present in oldRelatedPublish then we just set
            # relatedPublish's _documents and call changed to send updated fields
            # (Meteor sends only a diff).
            if oldRelatedPublish?._documents[collectionName]?[stringId]
              Meteor._ensure(relatedPublish._documents, collectionName)[stringId] = true
              @changed collectionName, id, fields
            else
              relatedPublishAdded.call @, collectionName, id, fields

          relatedPublish.ready = -> # Noop

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

        publish.ready()

        publish.onStop ->
          for handle, i in handleRelatedDocuments
            handle?.stop()
            handleRelatedDocuments[i] = null
          relatedPublish?.stop()
          relatedPublish = null

      func.apply publish, args
