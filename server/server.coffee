throw new Meteor.Error( 500, "No `Settings' defined (need server/_settings.coffee)" ) unless Settings?

Accounts.onCreateUser( (options, user) ->
    if Settings.DOMAIN? && ! user.services.google.email.match( Settings.DOMAIN )
        throw new Meteor.Error(403, "Unauthorized")

    users = Meteor.users.find({})
    if ( users.count() == 0 )
        user.group = 'admin'

    user.profile = {starredPages: []}

    user
)

Meteor.publish("userData", ->
    Meteor.users.find({_id: this.userId}, {fields: {'username': 1, 'group': 1, 'profile': 1}})
)

Meteor.publish("allUserData", () ->
  Meteor.users.find({}, {fields: {'username': 1}});
)

Meteor.publish('revisions', -> Revisions.find({}))

Meteor.publish('entries', (context) ->

    # Todo: Temporary
    return Entries.find({})

    # Todo: Use when Meteor gets aggregates
    user = Meteor.users.findOne({_id: this.userId}) if this.userId

    # Admins see all!
    if user && user.group == "admin"
        return Entries.find({})

    conditions = [{$ne: ["$entry.mode", "private"]}]

    if user
        conditions.push( {$eq: ["$entry.context": user.username] } ) if user.username
        conditions.push( {$eq: ["$entry.context": user.group] } )    if user.group
    
    visible = {$or: conditions}

    entries = Entries.aggregate
                $project:
                    title: true
                    mode: true
                    context: true
                    tags: {$cond: [visible, "$tags", ""]}
                    text: {$cond: [visible, "$text", ""]}
)


Meteor.publish('tags', -> return Tags.find({}))

Meteor.methods

    updateTitle: (entry, title, callback) ->
        throw new Meteor.Error(403, "You must be logged in") unless this.userId
        return Entries.update( {_id: entry._id}, {$set: {'title': title}} )

    # Todo: lock down fields
    saveEntry: (entry, context, callback) ->
        # Only members can edit
        user = Meteor.user()
        entry = verifySave( entry, user, context )
        entry.context = context

        if entry._id
            Entries.update({_id: entry._id}, entry)
            id = entry._id
        else
            id =  Entries.insert(entry)

        Revisions.insert( { entryId: id, date: new Date(), text: entry.text, author: user._id } )

        return id

    lockEntry: ( entryId ) ->
        Entries.update( {_id: entryId}, {$set: {"editing": true}}) if entryId

    unlockEntry: ( entryId ) ->
        Entries.update( {_id: entryId}, {$set: {"editing": false}}) if entryId

    updateUser: (value) ->
        throw new Meteor.Error(403, "You must be logged in") unless this.userId

        existing = Meteor.users.find( {"username": value} ).count()
        throw new Meteor.Error(403, "Username exists") if existing > 0

        Meteor.users.update( {_id: this.userId}, {$set: {"username": value}}) if value

    createNewPage: () ->
        #ownUnnamedPages = Entries.find( { author : this.userId, title : {$regex: /^unnamed-/ }}, {sort: { title: 1 }}).fetch() # .find(query, projection)
        ownUnnamedPages = Entries.find( { context: null, title : {$regex: /^unnamed-/ }}, {sort: { title: 1 }}).fetch() # .find(query, projection)
        if ownUnnamedPages.length == 0
            console.log('1')
            return 'unnamed-1'
        else
            seq = 1
            posted = false
            for page in ownUnnamedPages
                in_array = false
                for array_slice, i in ownUnnamedPages
                    if array_slice[i] == 'unnamed-'+seq
                        in_array = true
                        break
                    seq = seq + 1
                if in_array
                    seq = 0
                    continue
                else
                    return 'unnamed-'+seq
            next_seq = ownUnnamedPages.length + 1     
            return 'unnamed-'+next_seq   

    saveFile: (blob, name, path, encoding) ->
        throw new Meteor.Error(403, "You must be logged in") unless this.userId

        cleanPath = (str) ->
          if str
            str.replace(/\.\./g,'').replace(/\/+/g,'').replace(/^\/+/,'').replace(/\/+$/,'')

        cleanName = (str) ->
          str.replace(/\.\./g,'').replace(/\//g,'')

        path = cleanPath(path)
        fs = __meteor_bootstrap__.require('fs')
        name = cleanName(name || 'file')
        encoding = encoding || 'binary'
        chroot = 'public'

        path = chroot + (if path then '/' + path + '/' else '/')

        path = "public/user-images/#{this.userId}/"

        fs.mkdirSync( path ) if ! fs.existsSync( path )

        fs.writeFile(path + name, blob, encoding, (err) ->
          if err
            console.log( "err" );
          else
            console.log('The file ' + name + ' (' + encoding + ') was saved to ' + path)
        );

        return {filelink: path + name}




# Do not allow account creation by just anyone
Accounts.config forbidClientAccountCreation: true
  
# Verify that the admin user account exists (should be created on the first run)
u = Meteor.users.findOne(username: "admin") # find the admin user
unless u
    Accounts.createUser
    username: "admin"
    password: "abc123"
    profile:
        name: "Administrator"

Meteor.publish "systemUsers", ->
    if @userId
        Meteor.users.find
            username:
                $ne: "admin"
        ,
        sort:
            userId: 1

        fields:
            username: 1
            profile: 1
            emails: 1
            permissions: 1


Meteor.methods
    removeUser: (userId) ->
        throw new Meteor.Error(401, "Only admin is allowed to do this.")  unless Meteor.ManagedUsers.isAdmin()
        throw new Meteor.Error(401, "Admin can not be removed.")  if Meteor.user()._id is userId
        Meteor.users.remove userId
        true

    # updateUser: (userId, username, name, address, permissions) ->
    #     throw new Meteor.Error(401, "Only admin is allowed to do this.")  unless Meteor.ManagedUsers.isAdmin()
    #     Meteor.ManagedUsers.checkUsername username, userId
    #     throw new Meteor.Error(500, "Name can not be blank.")  unless name
    #     Meteor.ManagedUsers.checkEmailAddress address, userId
    #     if Meteor.user()._id is userId
    #         username = "admin"
    #         name = "Administrator"
    #     Meteor.users.update userId,
    #         $set:
    #             username: username
    #             profile:
    #                 name: name
    #             emails: [address: address]
    #             permissions: permissions
    #     userId

    # passwordReset: (userId) ->
    #     throw new Meteor.Error(401, "Only admin is allowed to do this.")  unless Meteor.ManagedUsers.isAdmin()
    #     try
    #         Accounts.sendResetPasswordEmail userId
    #     catch e
    #         throw new Meteor.Error(500, "Can't send email.")
    #     userId

    # addUser: (username, name, address, permissions) ->
    #     throw new Meteor.Error(401, "Only admin is allowed to do this.")  unless Meteor.ManagedUsers.isAdmin()
    #     Meteor.ManagedUsers.checkUsername username
    #     throw new Meteor.Error(500, "Name can not be blank.")  unless name
    #     Meteor.ManagedUsers.checkEmailAddress address
    #     newUserId = Accounts.createUser(
    #         username: username
    #         email: address
    #         profile:
    #         name: name
    #     )
    #     Accounts.sendEnrollmentEmail newUserId  if address
    #     Meteor.users.update newUserId,
    #         $set:
    #             permissions: permissions
    #     newUserId

# if Meteor.isClient
#   Meteor.subscribe "systemUsers"
  
#   # Use username or an optional email adddress for login
#   Accounts.ui.config passwordSignupFields: "USERNAME_AND_OPTIONAL_EMAIL"
  
#   # A shared Handlebars helper that returns true when the logged in user is "admin"
#   Handlebars.registerHelper "isAdmin", ->
#     Meteor.ManagedUsers.isAdmin()

  
#   # The current user's full name
#   Handlebars.registerHelper "profileName", ->
#     Meteor.user().profile.name  if Meteor.user() and Meteor.user().profile and Meteor.user().profile.name

  
#   # Pass a user object, and get the email address
#   Handlebars.registerHelper "emailAddress", (user) ->
#     user.emails[0].address  if user and user.emails

  
#   # Pass the permission name (as a string) to this helper
#   Handlebars.registerHelper "hasPermission", (permission) ->
#     true  if Meteor.user() and ((Meteor.user().username is "admin") or (Meteor.user().permissions and _.contains(Meteor.user().permissions,
#       permission: true
#     )))
