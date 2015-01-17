package app.api;

#if server
	import dtx.DOMCollection;
	import haxe.Json;
	import sys.FileSystem;
	import sys.io.File;
#end

import app.model.SiteMap;
import app.model.Manual;
import ufront.web.HttpError;
using Lambda;
using tink.CoreApi;
using haxe.io.Path;
using StringTools;
using Detox;

class ManualUpdateApi extends ufront.api.UFApi {

	@inject("contentDirectory") public var contentDir:String;

	var mdDir:String;
	var htmlDir:String;

	/**
		Convert Markdown to HTML

		@param `mdDir` the absolute path to the Markdown directory
		@param `htmlDir` the absolute path to the HTML output directory
		@throw error message (String)
	**/
	public function convertMarkdownToHtml( mdDir:String, htmlDir:String ):Void {

		this.mdDir = mdDir;
		this.htmlDir = htmlDir;

		if ( !FileSystem.exists(mdDir) ) 
			throw 'Markdown directory $mdDir did not exist during manual import';
		if ( !FileSystem.exists(htmlDir) ) 
			try FileSystem.createDirectory( htmlDir ) catch ( e:Dynamic ) throw 'Failed to create directory $htmlDir during manual import';

		var sectionsJson = File.getContent( '$mdDir/sections.txt' );
		var sections:Array<ManualSectionJson> = Json.parse( sectionsJson );
		var validSections = processSections( sections );

		try {
			var sitemap = generateSiteMap( validSections );
			File.saveContent( '$htmlDir/sitemap.json', Json.stringify(sitemap) ); 
		}
		catch ( e:Dynamic ) throw 'Failed to create save $htmlDir/sitemap.json';

		// Process the dictionary manually because it's not in "sections.txt"
		var dictionarySection = {
			label: "dictionary",
			id: "0",
			sub: [],
			state: 0,
			title: "Dictionary",
			index: 0,
			source: { file: "", lineMin:0, lineMax:0 }
		}
		processSection( dictionarySection );
	}

	/**
		Read the sections JSON and generate a Sitemap JSON we can use.
	**/
	function generateSiteMap( sections:Array<ManualSectionJson> ):SiteMap {
		var siteMap:SiteMap = [];
		var linkBase = app.Config.app.manual.editLinkBase;
		for ( section in sections ) {
			var fileAndLines = '${section.source.file}#L${section.source.lineMin}-${section.source.lineMax}';
			var page:SitePage = {
				title: section.title,
				url: section.label+".html",
				editLink: '$linkBase$fileAndLines'
			}
			if ( section.sub!=null && section.sub.length>0 ) {
				page.sub = generateSiteMap( section.sub );
			}
			siteMap.push( page );
		}
		return siteMap;
	}

	/**
		Go through an array of sections and process them into HTML
		Sometimes a section exists in the JSON but not in the markdown.  
		Return an array of sections, but only including those that exist, so that in our menu we only display those that exist.
	**/
	function processSections( sections:Array<ManualSectionJson> ):Array<ManualSectionJson> {
		var validSections = [];
		for ( section in sections ) {
			var existed = processSection( section );
			if ( existed )
				validSections.push( section );
			
			if ( section.sub!=null ) 
				section.sub = processSections( section.sub );
		}
		return validSections;
	}

	/**
		Read the markdown file, parse as XML, and do some filtering.
		The markdown lacks some markup we need, for example, classes on the "previous" and "next" links so we can style them appropriately.
		We also need to redirect links (if relative, change extension from `.md` to `.html`), and we need to process images.
	**/
	function processSection( section:ManualSectionJson ):Bool {
		var filename = '$mdDir/${section.label}.md';
		var outFilename = '$htmlDir/${section.label}.html';

		if ( FileSystem.exists(filename) ) {
			var markdown = File.getContent( filename );
			var html = Markdown.markdownToHtml( markdown );

			var xml = "div".create().setInnerHTML( html );

			var titleNode:DOMNode = null;
			var endOfContentNode:DOMNode = null;

			if ( xml.children().length>0 ) {
				for ( node in xml.children() ) {
					if ( endOfContentNode==null ) {
						switch node.tagName() {
							case "hr":
								// A "---" in the markdown signifies the end of the page content, and the beginning of the navigation links.
								endOfContentNode = node;
							case "h2":
								var text = node.text().trim();
								var id = text.substr( 0, text.indexOf(" ") );
								var title = text.substr( text.indexOf(" ")+1 );
								var h1 = "h1".create().setInnerHTML( '<small>$id</small> $title' );
								titleNode = h1;
								node.replaceWith( h1 );
							case "h3", "h4", "h5", "h6":
								var bookmarkID = node.text().trim().toLowerCase().replace(" ","-");
								var link = 'a'.create().setAttr( 'href', '#'+bookmarkID );
								var anchor = 'a'.create().setAttr( 'id', bookmarkID ).addClass( 'anch' );
								link.append( node.children(false) ).appendTo( node );
								node.beforeThisInsert( anchor );
								processNodes( link );
							case "blockquote":
								var firstElm = node.firstChildren();
								if ( firstElm.tagName()=="h5" ) {
									if ( firstElm.text().startsWith("Define") ) node.addClass("define");
									else if ( firstElm.text().startsWith("Trivia") ) node.addClass("trivia");
								}
								processNodes( node );
							default: 
								processNodes( node );
						}
					}
					else {
						node.removeFromDOM();
					}
				}
				html = xml.innerHTML();
			}
			else {
				try Xml.parse( html ) catch ( e:Dynamic ) {
					ufTrace( 'Failed to parse XML for ${section.label}, we will use it unprocessed. Error message: $e' );
				}
			}

			try File.saveContent( outFilename, html ) catch ( e:Dynamic ) throw 'Failed to write to file $outFilename';

			return true;
		}
		else {
			ufError('Section ${section.id} ${section.state} was not found [$filename]');
			return false;
		}
	}

	/**
		Look through manual content for nodes that need markup transformation.

		So far:

		- Links, will need the `href="something.md"` transformed into `href="something.html"`
		- Tables will have "table table-bordered" classes added for styling.
		- Images, will need paths altered.
	**/
	function processNodes( top:DOMNode ):Void {
		var thisAndDescendants = top.descendants( true ).add( top );
		for ( node in thisAndDescendants ) if ( node.isElement() ) {
			switch node.tagName() {
				case "a": 
					node.setAttr( "href", node.attr("href").replace(".md",".html") );
				case "table":
					node.addClass( "table table-bordered" );
				case "img":
					var src = node.attr( 'src' );
					src = "/manual/"+src.withoutDirectory();
					node.setAttr( 'src', src );
				default:
			}
		}
	}
}
