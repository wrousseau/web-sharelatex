define [
	"utils/Modal"
	"settings/DropboxSettingsManager"
], (Modal, DropboxSettingsManager) ->
	class SettingsManager
		templates:
			settingsPanel: $("#settingsPanelTemplate").html()

		constructor: (@ide, options) ->
			options || = {}
			setup = _.once =>
				@bindToProjectName()
				@bindToPublicAccessLevel()
				@bindToCompiler()
				@bindToRootDocument()
				@bindToSpellingPreference()

			new DropboxSettingsManager @ide

			@setFontSize()

			if @ide?
				@ide.on "afterJoinProject", (project) =>
					@project = project
					setup()

			settingsPanel = $(@templates.settingsPanel)
			@ide.tabManager.addTab
				id: "settings"
				name: "Settings"
				content: settingsPanel
				lock: true

			$('#DownloadZip').click (event)=>
				event.preventDefault()
				@ide.mainAreaManager.setIframeSrc "/project/#{@ide.project_id}/download/zip"

			$("#deleteProject").click (event)=>
				event.preventDefault()
				self = @
				deleteProject = ->
					self.ide.socket.emit 'deleteProject', ->
						window.location = '/'
				modalOptions =
					templateId:'deleteEntityModal'
					isStatic: false
					title:'Supprimer le Projet'
					message: "Êtes-vous sûr(e) de vouloir supprimer ce projet ?"
					buttons: [{
							text     : "Annuler",
							class    : "btn",
						}, {
						text     : "Suppression Définitive",
						class    : "btn-danger confirm",
						callback : deleteProject
					}]
				Modal.createModal modalOptions

			$('.cloneProject').click (event)=>
				event.stopPropagation()
				event.preventDefault()
				goToRegPage = ->
					window.location = "/register"

				modalOptions =
					isStatic: false
					title:'Enregistrement Requis'
					message: "Vous devez être enregistré(e) pour cloner un projet."
					buttons: [{
							text     : "Annuler",
							class    : "btn",
						}, {
						text     : "S'enregistrer Maintenant",
						class    : "btn-success confirm",
						callback : goToRegPage
					}]

				user = @project.get("ide").user
				if user.id == "openUser"
					return Modal.createModal modalOptions

				$modal = $('#cloneProjectModal')
				$confirm = $('#confirmCloneProject')
				$modal.modal({backdrop:true, show:true, keyboard:true})
				$modal.find('input').val('').focus()
				self = @
				$confirm.click (e)->
					$confirm.attr("disabled", true)
					$confirm.text("Clonage...")
					projectName = $modal.find('input').val()
					$.ajax

						url: "/project/#{self.ide.project_id}/clone"
						type:'POST'
						data:
							projectName: projectName
							_csrf: window.csrfToken
						success: (data)->
							if data.redir?
								window.location = data.redir
							else if data.project_id?
								window.location = '/project/'+data.project_id
				$modal.on 'hide', ->
					$confirm.off 'click'
				$modal.find('.cancel').click (e)->
					$modal.modal('hide')

		setFontSize: () ->
			@fontSizeCss = $("<style/>")
			@fontSizeCss.text """
				.ace_editor, .ace_content {
					font-size: #{window.userSettings.fontSize}px;
				}
			"""
			$(document.body).append(@fontSizeCss)

		bindToProjectName: () ->
			@project.on "change:name", (project, newName) ->
				$element = $('.projectName')
				$element.text(newName)
				window.document.title = newName
				$("input.projectName").val(newName)

			$("input.projectName").on "change", (e)=>
				# Check if event was triggered by the user, re:
				# http://stackoverflow.com/questions/6692031/check-if-event-is-triggered-by-a-human
				if e.originalEvent?
					if @ide.isAllowedToDoIt "readAndWrite"
						@project.set("name", e.target.value)

		bindToCompiler: ->
			$('select#compilers').val(@project.get("compiler"))

			$('select#compilers').change (e)=>
				if @ide.isAllowedToDoIt "readAndWrite"
					@project.set("compiler", e.target.value)



		bindToSpellingPreference: ->

			$('select#spellCheckLanguageSelection').on "change", (e)=>
				languageCode = e.target.value
				@project.set("spellCheckLanguage", languageCode)


		bindToRootDocument: () ->
			$('#rootDocList').change (event)=>
				docId = $(event.target).val()
				@project.set("rootDoc_id", docId)

			# Repopulate the root document list when the settings page is shown. Updating
			# it in real time is just a little too complicated
			do refreshDocList = =>
				$docList = $('select#rootDocList')
				$docList.empty()
				@project.getRootDocumentsList (listOfDocs) =>
					template = _.template($('#rootDocListEntity').html())
					_.each listOfDocs, (doc)=>
						option = $(template(name:doc.path))
						option.attr('value', doc._id)
						$docList.append(option)
					hasRootDoc = _.find listOfDocs, (doc)=>
						if doc._id == @project.get("rootDoc_id")
							return true
					if hasRootDoc
						$docList.val(@project.get("rootDoc_id"))
					else
						option = $(template(name:"Aucun Document Principal Sélectionné !"))
						option.attr('value', 'blank')
						$docList.append(option)
						$docList.val('blank')

			$('#settings-tab-li').on "click", refreshDocList

		bindToPublicAccessLevel: () ->
			$('select#publicAccessLevel').val(@project.get("publicAccesLevel"))

			@project.on "change:publicAccesLevel", (project, level) ->
				$('select#publicAccessLevel').val(level)

			$("select#publicAccessLevel").on "change", (event)=>
				newSetting = event.target.value
				cancelChange = =>
					@project.set("publicAccesLevel", "private")
				doChange = () =>
					@project.set("publicAccesLevel", newSetting)
				modalOptions =
					buttons: [{
						text     : "Annuler",
						class    : "btn",
						callback : cancelChange
					},{
						text     : "OK",
						class    : "btn-danger confirm",
						callback : doChange
					}]

				if newSetting == 'readOnly'
					modalOptions.title = 'Rendre le Projet Public - Lecture Seule'
					modalOptions.message = 'Êtes-vous sûr(e) de vouloir rendre le projet public ? Google et autres moteurs de recherche seront capable de le trouver. Les utilisateurs ne pourront pas éditer le projet.'
				else if newSetting == 'readAndWrite'
					modalOptions.title = 'Rendre le Projet Public - Lecture et Ecriture'
					modalOptions.message = 'Êtes-vous sûr(e) de vouloir rendre le projet public ? Google et autres moteurs de recherche seront capable de le trouver. Les utilisateurs pourront éditer le projet.'
				if newSetting == 'private'
					modalOptions.title = 'Rendre le Projet Privé'
					modalOptions.message = 'Êtes-vous sûr(e) de vouloir rendre le projet privé ? Seuls les utilisateurs enregistrés avec les bonnes permissions pourront voir le projet.'

				Modal.createModal modalOptions


