root = exports ? this
root.Entries = new Meteor.Collection("entries")
root.Tags = new Meteor.Collection("tags")
root.Revisions = new Meteor.Collection("revisions")

root.escapeRegExp = (str) ->
  str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")

Entries.allow
  insert: (userId, entry) -> false

  update: (userId, entries, fields, modifier) -> false

  remove: (userId, entries) -> false

Tags.allow
    insert: (userId, entry) -> true if userId


root.entryLink = ( entry ) ->
    unless entry.context then "/#{entry.title}" else "/u/#{entry.context}/#{entry.title}"

# Admins can admin anywhere, others can only admin in context
root.adminable = ( user, context ) ->
    user &&
    ( user.group == "admin" ||
      user.group == context ||
      user.username == context )

# View all in context, view public and read-only otherwise
root.viewable = ( entry, user, context ) ->
    adminable( user, context ) ||
    ( context == null && (entry == null || !entry._id?) ) ||
    ( entry && entry.mode != "private" )

# Edit in context or public entries
root.editable = ( entry, user, context ) ->
    user && 
    ( adminable( user, context ) ||
      ( context == null && (entry == null || !entry._id?) ) ||
      ( entry && entry.mode == "public" ) )


root.verifySave = ( entry, user, context ) ->

    bail = (message, status = 403) ->
        throw new Meteor.Error(status, message)

    # Only members can edit
    if ! user
        bail("You must be logged in")

    if ( entry._id )
        oldEntry = Entries.findOne({_id: entry._id})
        entry._id = null unless oldEntry

    # No dup titles in same context
    for other in Entries.find({context: context, _id: {$not: entry._id}})
        if other.title == entry.title
            bail( "Title taken" )

    # Admins can do anything
    return entry if user.group == "admin"

    # Non-admins may only edit public entries in root context
    if context == null && oldEntry && oldEntry.mode != "public"
        bail("Can't edit non-public entry")

    # Users may only edit in their own context or group context
    if context != null && context != user.username && context != user.group 
        bail("Only #{context} may edit")

    # Non-admins may only create public entries in root context
    if context == null
        entry.mode = "public"

    entry







Meteor.ManagedUsers =
    # availablePermissions: ->
    # # Return an object of key/value pairs, like:  {permissionName: "Permission Description", ....}
    # # Do this in a file accessible by both the server and client.
    #     {}

  
    # Input Validation
    isAdmin: ->
        Meteor.user() and (Meteor.user().username is "admin")

    # checkUsername: (username, userId) ->
    #     throw new Meteor.Error(500, "Username can not be blank.")  unless username
    #     usernamePattern = /^[a-z]+$/g
    #     throw new Meteor.Error(500, "Username format is incorrect.")  unless usernamePattern.test(username)
    #     u = Meteor.users.findOne(username: username)
    #     throw new Meteor.Error(500, "Username already in use.")  if u and (not userId or (u._id isnt userId))

    # checkEmailAddress: (address, userId) ->
    # if address
    #     emailPattern = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i
    #     throw new Meteor.Error(500, "Email Address format is incorrect.")  unless emailPattern.test(address)
    #     u = Meteor.users.findOne(emails:
    #         $elemMatch:
    #             address: address
    #     )
    #     throw new Meteor.Error(500, "Email Address already in use.")  if u and (not userId or (u._id isnt userId))
