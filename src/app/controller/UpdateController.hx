package app.controller;

import app.api.*;
import app.Config;
import ufront.web.Controller;
import ufront.web.Dispatch;
import ufront.web.result.ViewResult;
import ufront.view.TemplateData;
using StringTools;
using tink.CoreApi;
using haxe.io.Path;
using Detox;

class UpdateController extends Controller {
	
	@inject("contentDirectory") public var contentDir:String;
	@inject public var siteApi:SiteApi;
	@inject public var manualApi:ManualUpdateApi;
	@inject public var downloadApi:DownloadApi;

	@:route("/site/")
	public function doSite() {
		var assetSiteContent = context.request.scriptDirectory+Config.app.siteContent.folder;
		var ufSiteContent = contentDir+Config.app.siteContent.folder;
		var downloadInDir = assetSiteContent+'/'+Config.app.siteContent.versions.folder;
		var downloadOutDir = ufSiteContent+'/'+Config.app.siteContent.versions.folder;

		var gitRepo = Config.app.siteContent.repo;
		var branch = Config.app.siteContent.branch;
		var repoDir = contentDir+Config.app.siteContent.cloneDir+'/';
		var forceDelete = false;
		// siteApi.cloneRepo( gitRepo, repoDir, branch, forceDelete );
		
		downloadApi.prepareDownloadJson(downloadInDir,downloadOutDir);

		return new ViewResult({
			title: 'Updated the website content succesfully',
			content: '<h1>Updated the website content successfully.</h1>'
		}, "/page/page-without-sidebar.html");
		// return Server.requestCache.invalidate() >> function(_:Noise) {
		// }
	}

	@:route("/manual/")
	public function doManual() {

		var forceDelete = false;
		var gitRepo = Config.app.manual.repo;
		var branch = Config.app.manual.branch;
		var manualDir = contentDir+Config.app.manual.dir+'/';
		var manualMdDir = contentDir+Config.app.manual.mdDir;
		var manualHtmlDir = contentDir+Config.app.manual.htmlDir;
		
		siteApi.cloneRepo( gitRepo, manualDir, branch, forceDelete );
		manualApi.convertMarkdownToHtml(manualMdDir,manualHtmlDir);

		return new ViewResult({
			title: 'Updated the manual succesfully',
			content: '<h1>Updated the manual successfully.</h1>'
		}, "/page/page-without-sidebar.html");
		// return Server.requestCache.invalidate() >> function(_:Noise) {
		// }
	}
}
