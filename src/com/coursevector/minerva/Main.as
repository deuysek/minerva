import com.coursevector.data.JSFormatter;
import com.coursevector.flex.AlertBox;
import com.coursevector.formats.AMF;
import com.coursevector.formats.SOL;
import com.coursevector.minerva.AboutPanel;
import com.coursevector.minerva.AddVar;
import com.dusk.net.NativeFile;
import com.hurlant.util.Base64;

import flash.desktop.Clipboard;
import flash.desktop.ClipboardFormats;
import flash.desktop.ClipboardTransferMode;
import flash.desktop.NativeApplication;
import flash.desktop.NativeDragActions;
import flash.desktop.NativeDragManager;
import flash.display.StageScaleMode;
import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.InvokeEvent;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.events.NativeDragEvent;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.net.FileFilter;
import flash.net.SharedObject;
import flash.net.SharedObjectFlushStatus;
import flash.utils.ByteArray;
import flash.utils.CompressionAlgorithm;
import flash.utils.describeType;
import flash.utils.getDefinitionByName;
import flash.utils.setTimeout;
import flash.xml.XMLDocument;

import mx.collections.ArrayCollection;
import mx.controls.TextInput;
import mx.controls.Tree;
import mx.controls.listClasses.IListItemRenderer;
import mx.controls.treeClasses.TreeItemRenderer;
import mx.controls.treeClasses.TreeListData;
import mx.core.IUITextField;
import mx.core.mx_internal;
import mx.events.ListEvent;
import mx.events.ToolTipEvent;
import mx.managers.PopUpManager;
import mx.utils.ArrayUtil;

import spark.events.IndexChangeEvent;

[Embed("/assets/icons/array.png")]
private var arrayIcon:Class;

[Embed("/assets/icons/boolean.png")]
private var booleanIcon:Class;

[Embed("/assets/icons/bytearray.png")]
private var bytearrayIcon:Class;

[Embed("/assets/icons/date.png")]
private var dateIcon:Class;

[Embed("/assets/icons/int.png")]
private var intIcon:Class;

[Bindable]
[Embed("/assets/icons/null.png")]
private var nullIcon:Class;

[Embed("/assets/icons/number.png")]
private var numberIcon:Class;

[Embed("/assets/icons/object.png")]
private var objectIcon:Class;

[Embed("/assets/icons/string.png")]
private var stringIcon:Class;

[Embed("/assets/icons/undefined.png")]
private var undefinedIcon:Class;

[Embed("/assets/icons/xml.png")]
private var xmlIcon:Class;

[Embed("/assets/icons/vector.png")]
private var vectorIcon:Class;

[Bindable]
private var showInspector:Boolean = false;

[Bindable]
private var hasFile:Boolean = false;

[Bindable]
private var showOpen:Boolean = true;

[Bindable]
private var showSave:Boolean = false;

[Bindable]
private var arrDataTypes:Array = [
	'Array', 'Boolean', 'ByteArray', 'Date',
	'Integer', 'Null', 'Number', 'Object',
	'String', 'Undefined', 'XML', 'XMLDocument'
];
// Minerva
//private var appUpdater:ApplicationUpdaterUI = new ApplicationUpdaterUI();
private var aboutWin:AboutPanel;

[Bindable]
private var isEditor:Boolean = true;

private var isStartEdit:Boolean = false;
private var lastSelected:Object;

// JS Formatter
private var objJSConfig:Object = {};
private var fmtrJS:JSFormatter = new JSFormatter();

// AMF Editor
private var isJSON:Boolean = false;
private var isSOL:Boolean = false;
private var fileRead:File = File.userDirectory;
private var fileWrite:File = File.desktopDirectory;
private var fileExport:File = File.desktopDirectory;
[Bindable]
private var objData:Object = {};
private var nVersion:int = -1;
private var solReader:SOL = new SOL();
private var amfReader:AMF = new AMF();
private var fileFilters:Array = [
	new FileFilter("SOL Files", "*.sol", "SOL"),
	new FileFilter("Remoting AMF Files", "*.amf", "AMF")
];
// For Sorting the Tree
private var _uid:int = 0;
[Bindable]
private var _dataProvider:ArrayCollection = new ArrayCollection([objData]);
private var _openItems:Array;
private var _verticalScrollPosition:Number;
private var siteMapIDField:String = "id";
private var sortLabelField:String = "name-asc";
private var sortItems:Boolean = true;
private var rememberOpenState:Boolean = false;

use namespace mx_internal;

/////////////////
// Application //
/////////////////

// Event handler to initialize the MenuBar control.
private function init():void {
	// Init Updater
	// appUpdater.updateURL = "http://www.coursevector.com/projects/minerva/update.xml"; // Server-side XML file describing update
	// appUpdater.isCheckForUpdateVisible = false; // We won't ask permission to check for an update
	// appUpdater.addEventListener(UpdateEvent.INITIALIZED, onUpdate); // Once initialized, run onUpdate
	// appUpdater.addEventListener(ErrorEvent.ERROR, errorHandler); // If something goes wrong, run onError
	// appUpdater.initialize(); // Initialize the update framework

	// Load prefs
	var so:SharedObject = SharedObject.getLocal("settings");
	objJSConfig.space_after_anon_function = true;
	if (so.data.hasOwnProperty("indent_index")) {
		ddSize.selectedIndex = so.data.indent_index;

		objJSConfig.indent_size = ddSize.selectedItem.value;
		objJSConfig.indent_char = objJSConfig.indent_size == 1 ? '\t' : ' ';
		objJSConfig.braces_on_own_line = so.data.braces_on_own_line;
		objJSConfig.preserve_newlines = so.data.preserve_newlines;
		objJSConfig.detect_packers = so.data.detect_packers;
		objJSConfig.keep_array_indentation = so.data.keep_array_indentation;

		cbBraces.selected = objJSConfig.braces_on_own_line;
		cbPreserve.selected = objJSConfig.preserve_newlines;
		//cbKeepIndentation.selected = objJSConfig.keep_array_indentation;
	}

	// Init Listeners
	this.addEventListener(NativeDragEvent.NATIVE_DRAG_ENTER, dragHandler);
	this.addEventListener(NativeDragEvent.NATIVE_DRAG_DROP, dragHandler);
	NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE, invokeHandler, false, 0, true);
	solReader.addEventListener(ErrorEvent.ERROR, errorHandler, false, 0, true);
	solReader.addEventListener(Event.COMPLETE, openCompleteHandler, false, 0, true);
	amfReader.addEventListener(ErrorEvent.ERROR, errorHandler, false, 0, true);
	amfReader.addEventListener(Event.COMPLETE, openCompleteHandler, false, 0, true);
}

private function onAdded():void {
	// Analytics
	// var tracker:AnalyticsTracker = new GATracker(this.stage, "UA-349755-1", "AS3", false);
	// tracker.trackPageview("/tracking/projects/minerva");
	stage.scaleMode = StageScaleMode.SHOW_ALL;
	stage.align = "";
}

private function invokeHandler(e:InvokeEvent):void {
	if (e.arguments.length > 0) {
		var l:int = e.arguments.length;
		var invCommands:Object = {};
		while (l--) {
			invCommands[e.arguments[l].toLowerCase()] = e.arguments[l];
		}

		if (fileRead.hasEventListener(Event.SELECT)) fileRead.removeEventListener(Event.SELECT, openHandler);
		fileRead = new File(e.arguments[0]);
		openHandler();
		if (invCommands['json-export']) {
			fileExport = new File(fileWrite.url);
			saveJSONHandler();
		}
		if (invCommands['exit']) this.close();
	}
}

private function onChangePage(evt:IndexChangeEvent):void {
	if (evt.newIndex == 0) {
		vsNav.selectedIndex = 0;
		isEditor = true;
		showOpen = isEditor && !hasFile;
		showSave = isEditor && hasFile;
	} else {
		vsNav.selectedIndex = 1;
		isEditor = false;
		showOpen = false;
		showSave = false;
	}
}

private function onClickAbout():void {
	aboutWin = new AboutPanel();
	//var panel:SettingPanel = new SettingPanel;
	PopUpManager.addPopUp(aboutWin, this, true);
}

private function fileClose():void {
	objData = {};
	nVersion = -1;
	updateTreedataProvider(new ArrayCollection([objData]));
	showInspector = false;
	hasFile = false;
	showOpen = isEditor && !hasFile;
	showSave = isEditor && hasFile;
	isSOL = false;
	title = "Minerva Sol Editor";
}

private function dragHandler(e:NativeDragEvent):void {
	switch (e.type) {
		case NativeDragEvent.NATIVE_DRAG_ENTER :
			var cb:Clipboard = e.clipboard;
			if (cb.hasFormat(ClipboardFormats.FILE_LIST_FORMAT)) {
				NativeDragManager.dropAction = NativeDragActions.LINK;
				NativeDragManager.acceptDragDrop(this);
			} else {
				AlertBox.show(LocaleManager.getIns().getLangString("Error.UnknowFileType"));
			}
			break;
		case NativeDragEvent.NATIVE_DRAG_DROP :
			var arrFiles:Array = e.clipboard.getData(ClipboardFormats.FILE_LIST_FORMAT, ClipboardTransferMode.ORIGINAL_ONLY) as Array;
			if (fileRead.hasEventListener(Event.SELECT)) fileRead.removeEventListener(Event.SELECT, openHandler);
			fileRead = arrFiles[0];
			openHandler();
			break;
	}
}

private function onUpdate(event:/*UpdateEvent*/Event):void {
	//appUpdater.checkNow(); // Go check for an update now
}

//////////////////////////
// JavaScript Formatter //
//////////////////////////

private function formatHandler(event:MouseEvent):void {
	trace(JSON.stringify(objJSConfig));
	txtCode.text = fmtrJS.format(txtCode.text.replace(/^\s+/, ''), objJSConfig);
}

private function updateConfig():void {
	objJSConfig.indent_size = ddSize.selectedItem.value;
	objJSConfig.indent_char = objJSConfig.indent_size == 1 ? '\t' : ' ';
	objJSConfig.braces_on_own_line = cbBraces.selected;
	objJSConfig.preserve_newlines = cbPreserve.selected;
	objJSConfig.space_after_anon_function = true;
	//objJSConfig.keep_array_indentation = cbKeepIndentation.selected;

	// Save Pref via Shared Object
	var so:SharedObject = SharedObject.getLocal("settings");
	so.data.braces_on_own_line = cbBraces.selected;
	so.data.preserve_newlines = cbPreserve.selected;
	so.data.indent_index = ddSize.selectedIndex;
	//so.data.keep_array_indentation = cbKeepIndentation.selected;

	var result:String = so.flush();
	if (result != SharedObjectFlushStatus.FLUSHED) AlertBox.show(LocaleManager.getIns().getLangString("Error.ErrorSavingSetting"));
}

////////////////
// SOL Editor //
////////////////

private function treeOverHandler(e:ListEvent):void {
	e.itemRenderer.addEventListener(ToolTipEvent.TOOL_TIP_SHOW, treeTipHandler, false, 0, true);
}

private function treeTipHandler(e:ToolTipEvent):void {
	var label:IUITextField = TreeItemRenderer(e.currentTarget).mx_internal::getLabel();
	var tarPosX:Number = e.toolTip.x + label.measuredWidth;
	if (systemManager.stage.mouseX + 10 > tarPosX) tarPosX = systemManager.stage.mouseX + 10;
	e.toolTip.move(tarPosX, e.toolTip.y);
}

private function onChangeSort(e:Event):void {
	sortLabelField = cbSort.selectedItem.data;
	onClickRefresh();
}

private function onClickRefresh():void {
	if (hasFile) {
		rememberOpenState = true;
		if (fileRead) openHandler();
		rememberOpenState = false;
	}
}

private function onClickInsert():void {
	var parent:Object = dataTree.selectedItem;
	if (parent == null) {
		AlertBox.show(LocaleManager.getIns().getLangString("Error.ParentNodeNeed"));
		return;
	}
	var win:AddVar = new AddVar();
	win.callBack = insertCallBack;
	win.setCurrentId(_uid + 1);
	PopUpManager.addPopUp(win, this, true);
	PopUpManager.centerPopUp(win);
}

/**
 * 添加变量回调
 * param [name,type]
 */
private function insertCallBack(param:Array):void {
	var parent:Object = dataTree.selectedItem;
	var o:Object = {name: param[0], type: arrDataTypes[param[1]], value: null, id: ++_uid};
	if (o.type == "Object" || o.type == "Array") {
		o.children = [];
		o.traits = {count: 0, members: [], type: o.type};
	}

	if (!dataTree.dataDescriptor.isBranch(parent)) parent = dataTree.getParentItem(parent);

	//if (!parent.children) parent = dataTree.getParentItem(parent);
	//var parentRenderer:IListItemRenderer = dataTree.itemToItemRenderer(parent);
	//var parentIndex:int = dataTree.itemRendererToIndex(parentRenderer);

	dataTree.dataDescriptor.addChildAt(parent, o, parent.children.length);

//	parent.children.push(o);
	if (parent.traits && parent.traits.count) {
		// Add member to members array
		parent.traits.members.push(o);

		// Increase member count
		parent.traits.count++;
	}

	_dataProvider.refresh();
	dataTree.invalidateList();

	//dataTree.selectedItem = parent;
	//如果选中的节点没有打开，会导致报错
	dataTree.selectedItem = o;
	switch (o.type) {
		case "Object":
			o.value = {};
			break;
		case "Array":
			o.value = [];
			break;
		case "ByteArray":
			o.value = new ByteArray();
			break;
		case "String":
		case "XML":
		case "XMLDocument":
			o.value = "";
			break;
		case "Number":
		case "Integer":
			o.value = 0;
			break;
		case "Boolean":
			o.value = false;
			break;
		case "Date":
			o.value = new Date();
			break;
		case "Null":
		case "Undefined":
		default:
	}
	if (dataTree.selectedItem) {
		dataTree.dispatchEvent(new ListEvent(Event.CHANGE));
	}
}

private function onClickRemove():void {
	var node:Object = dataTree.selectedItem;
	if (node == null) {
		AlertBox.show(LocaleManager.getIns().getLangString("Error.NodeSelectionNeed"));
		return;
	}

	var parent:Object = dataTree.getParentItem(node);
	var parentRenderer:IListItemRenderer = dataTree.itemToItemRenderer(parent);
	// If parent node is not in view, it can't be found
	if (parentRenderer == null) return;

	var p:int = dataTree.itemRendererToIndex(parentRenderer);
	var i:int = dataTree.itemRendererToIndex(dataTree.itemToItemRenderer(node));
	dataTree.dataDescriptor.removeChildAt(parent, dataTree.selectedItem, i - p - 1);
	vsType.selectedChild = ObjectType;

	if (parent.traits && parent.traits.count) {
		// Remove member from members array
		for (i = 0; i < parent.traits.count; i++) {
			if (parent.traits.members[i] == node.name) {
				parent.traits.members.splice(i, 1);
				break;
			}
		}

		// Reduce member count
		parent.traits.count--;
	}

	if (parent.type == "Array" || parent.type == "Object") {
		for (i = 0; i < parent.children; i++) {
			if (parent.children[i].id == node.id) {
				parent.children.splice(i, 1);
				break;
			}
		}
	}
}

private function fileOpen():void {
	// Find location of flashlog.txt
	var strUserDir:String = fileRead.url;
	if (fileRead.hasEventListener(Event.SELECT)) fileRead.removeEventListener(Event.SELECT, openHandler);
	fileRead = fileRead.resolvePath(strUserDir + "/Application Data/Macromedia/Flash Player/"); // Win
	if (fileRead.exists) {
		// Windows
	} else {
		fileRead = fileRead.resolvePath(strUserDir + "/Library/Preferences/Macromedia/Flash Player/"); // Mac
		if (fileRead.exists) {
			// Mac
		} else {
			fileRead = fileRead.resolvePath(strUserDir + "/.macromedia/Flash_Player/"); // Linux
			// Linux
		}
	}

	fileRead.addEventListener(Event.SELECT, openHandler, false, 0, true);
	fileRead.browseForOpen(LocaleManager.getIns().getLangString("FileOperate.Open"), fileFilters);
}

private function errorHandler(e:ErrorEvent):void {
	AlertBox.show(e.text);
}

private function openHandler(e:Event = null):void {
	// Update fileWrite
	if (fileExport.hasEventListener(Event.SELECT)) fileExport.removeEventListener(Event.SELECT, saveJSONHandler);
	if (fileWrite.hasEventListener(Event.SELECT)) fileWrite.removeEventListener(Event.SELECT, saveHandler);
	fileWrite = new File(fileRead.url);
	fileWrite.addEventListener(Event.SELECT, saveHandler, false, 0, true);
	fileExport.addEventListener(Event.SELECT, saveJSONHandler, false, 0, true);

	var ba:ByteArray = new ByteArray();

	// Read file into ByteArray
	var bytes:FileStream = new FileStream();
	bytes.open(fileRead, FileMode.READ);
	bytes.readBytes(ba);
	bytes.close();

	if (fileRead.extension.toLowerCase() == "amf") {
		isSOL = false;

		// Read AMF File
		if (CONFIG::debugging) {
			amfReader.deserialize(ba, systemManager);
		} else {
			try {
				amfReader.deserialize(ba, systemManager);
			} catch (err:Error) {
				AlertBox.show(err.message);
			}
		}
	} else {
		isSOL = true;

		// Read SOL File
		if (CONFIG::debugging) {
			solReader.deserialize(ba, systemManager);
		} else {
			try {
				solReader.deserialize(ba, systemManager);
			} catch (err:Error) {
				AlertBox.show(err.message);
			}
		}
	}

	// Display opening message
	updateTreedataProvider(new ArrayCollection([{name: LocaleManager.getIns().getLangString("Waiting.Loading")}]));

	showInspector = false;
	hasFile = true;
	showOpen = isEditor && !hasFile;
	showSave = isEditor && hasFile;
	vsType.selectedChild = EmptyType;

	this.title = "Minerva - " + fileRead.name;
}

private function openCompleteHandler(e:Event):void {
	var reader:Object = isSOL ? solReader : amfReader;
	// Grab AMF version
	nVersion = reader.amfVersion;

	// Convert Data to dataProvider object
	_uid = 0;
	objData = toDPObject(isSOL ? solReader.fileName : fileRead.name, reader.data);

	var fileSize:String = fileRead.size > 1024 ? Number(fileRead.size / 1024).toFixed(2) + "kb" : fileRead.size + "b";
	objData.type = "AMF" + nVersion + " (" + fileSize + ")";

	// Convert Object to an ArrayCollection
	updateTreedataProvider(new ArrayCollection(ArrayUtil.toArray(objData)));
}

//////////////////
// Sort Tree Functions

private function updateTreedataProvider(value:ArrayCollection):void {
	if (_dataProvider != null) saveTreeOpenState();

	_dataProvider = value;
	if (sortItems) {
		// Sort the Array Collection
		//_dataProvider.sort = getSort();

		// Sort the nested arrays of the ArrayCollection using recursion
		for (var i:int = 0; i < _dataProvider.length; i++) {
			sortTree(_dataProvider.getItemAt(i));
		}
		_dataProvider.refresh();
	}
	dataTree.dataProvider = _dataProvider;
	dataTree.validateNow();

	if (rememberOpenState) {
		for (var t:int = 0; t < _dataProvider.length; t++) {
			if (_dataProvider.getItemAt(t).hasOwnProperty("children")) {
				openTreeItems(_dataProvider.getItemAt(t));
			}
		}

		dataTree.verticalScrollPosition = _verticalScrollPosition;
	}
}

private function sortOnName(a:Object, b:Object):Number {
	if (!isNaN(Number(a.name))) {
		var aIndex:int = Number(a.name);
		var bIndex:int = Number(b.name);

		if (aIndex > bIndex) {
			return 1;
		} else if (aIndex < bIndex) {
			return -1;
		} else {
			//aIndex == bIndex
			return 0;
		}
	} else {
		var aName:String = a.name;
		var bName:String = b.name;

		if (aName > bName) {
			return 1;
		} else if (aName < bName) {
			return -1;
		} else {
			//aName == bName
			return 0;
		}
	}
}

private function sortOnType(a:Object, b:Object):Object {
	var aType:String = a.type;
	var bType:String = b.type;

	//sort first field
	if (aType < bType) {
		return -1;
	} else if (aType > bType) {
		return 1;
	}

	//if first field is the same, then sort on second field
	if (aType == bType) {
		if (!isNaN(Number(a.name))) {
			var aIndex:int = Number(a.name);
			var bIndex:int = Number(b.name);

			if (aIndex > bIndex) {
				return 1;
			} else if (aIndex < bIndex) {
				return -1;
			}
		} else {
			var aName:String = a.name;
			var bName:String = b.name;

			if (aName > bName) {
				return 1;
			} else if (aName < bName) {
				return -1;
			}
		}
	}

	return 0;
}

private function sortTree(object:Object):void {
	if (object.hasOwnProperty("children")) {
		if (sortLabelField.indexOf('type') > -1) {
			if (sortLabelField.indexOf('asc') > -1) {
				object.children.sort(sortOnType);
			} else {
				object.children.sort(sortOnType, Array.DESCENDING);
			}
		} else {
			if (sortLabelField.indexOf('asc') > -1) {
				object.children.sort(sortOnName);
			} else {
				object.children.sort(sortOnName, Array.DESCENDING);
			}
		}

		for (var t:int = 0; t < object.children.length; t++) {
			sortTree(object.children[t]);
		}
	}
}

private function openTreeItems(object:Object):void {
	for (var i:int = 0; i < _openItems.length; i++) {
		if (object[siteMapIDField] == _openItems[i]) {
			dataTree.expandItem(object, true);
			break;
		}
	}

	if (object.hasOwnProperty("children")) {
		for (var t:int = 0; t < object.children.length; t++) {
			openTreeItems(object.children[t]);
		}
	}
}

private function saveTreeOpenState():void {
	_verticalScrollPosition = dataTree.verticalScrollPosition;
	_openItems = [];
	for (var i:int = 0; i < dataTree.openItems.length; i++) {
		if (dataTree.openItems[i].hasOwnProperty(siteMapIDField)) {
			_openItems[i] = dataTree.openItems[i][siteMapIDField];
		}
	}
}

///////////////////

// Converts simple object to dataProvider object
private function toDPObject(name:String, value:*):Object {
	var o:Object = {};
	var type:String = determineType(value);

	if (type == "Array" || type == "Object" || type.indexOf('Vector') > -1) {
		// For custom classes, pass the class name and traits
		var traits:Object;
		if (type == "Object" && value.hasOwnProperty("__traits")) {
			type = value.__traits.type;
			traits = value.__traits;
			delete value.__traits;
		} else if (type.indexOf('Vector.<int>') == -1 &&
				type.indexOf('Vector.<uint>') == -1 &&
				type.indexOf('Vector.<Number>') == -1 &&
				type.indexOf('Vector') > -1) {
			type = value[0].type;
			traits = value[0];
			delete value.shift();
		}

		// Parent Object
		o = {name: name, type: type, id: _uid, traits: traits};
		o.children = [];

		// Child Objects
		// If data is a typed (class) object, for...in won't read it
		var desc:XML = describeType(value);
		name = desc.@name.toString();
		if (name.indexOf('::') != -1) name = name.split('::').pop();
		if (name.indexOf('Vector') > -1) {
			for (var i:int = 0, l:int = value.length; i < l; i++) {
				o.children.push(toDPObject(String(i), value[i]));
			}
		} else if (name != "Object" &&
				name != 'ObjectProxy' &&
				name != 'ManagedObjectProxy' &&
				name != "Array") {
			for each (var v:XML in desc.variable) {
				name = v.@name.toString();
				o.children.push(toDPObject(name, value[name]));
			}
		} else {
			for (name in value) {
				o.children.push(toDPObject(name, value[name]));
			}
		}
	} else if (type == "ByteArray") {
		o = {name: name, value: value, type: type, id: _uid};
	} else if (type == "XMLDocument" || type == "XML") {
		o = {name: name, value: value.toString(), type: type, id: _uid};
	} else {
		o = {name: name, value: value, type: type, id: _uid};
	}
	_uid++;

	return o;
}

// Converts dataProvider object to simple object
private function toObject(arr:Array, o:*):* {
	if (!arr) arr = [];
	if (!o) o = {};
	var l:uint = arr.length;
	for (var i:int = 0; i < l; ++i) {
		var data:Object = arr[i];
		var value:*;
		if (data.type == "ByteArray") {
			value = data.value;
		} else if (data.type == "Array") {
			value = toObject(data.children, []) as Array;
		} else if (data.type == "Object") {
			value = toObject(data.children, {});
		} else if (data.type == "Vector.<int>") {
			value = toObject(data.children, new Vector.<int>());
		} else if (data.type == "Vector.<uint>") {
			value = toObject(data.children, new Vector.<uint>());
		} else if (data.type == "Vector.<Number>") {
			value = toObject(data.children, new Vector.<Number>());
		} else if (data.type == "Vector.<Object>" || data.type.indexOf('Vector') > -1) {
			value = toObject(data.children, new Vector.<Object>());
		} else {
			var type:String = data.type;
			if (type == "Undefined") {
				value = undefined;
			} else if (type == "Null") {
				value = null;
			} else if (type == "Unsupported") {
				value = "__unsupported";
			} else {
				if (type == "Integer") type = "int";
				if (type == "int" && (data.value % 1 != 0)) type = "Number";
				if (type == "int" && (data.value >= int.MAX_VALUE || data.value <= int.MIN_VALUE)) {
					type = "Number";
					data.type = "Number";
				}
				if (type == "XMLDocument") type = "flash.xml.XMLDocument";

				try {
					var c:Class = getDefinitionByName(type) as Class;
					// Handle these differently, use the 'new' keyword
					if (type == "flash.xml.XMLDocument" || type == "Date") {
						value = new c(data.value);
					} else {
						value = c(data.value);
					}
				} catch (e:Error) {
					//type.indexOf('flex') >= -1
					value = toObject(data.children, {});
				}
			}
		}

		// Handle Vectors special
		if (data.type.indexOf('Vector') > -1 && data.traits) {
			value.unshift(data.traits);
		} else if (data.traits) {
			value.__traits = data.traits;
		}

		o[data.name] = value;
	}

	return o;
}

private function fileSaveAs():void {
	fileWrite.browseForSave(LocaleManager.getIns().getLangString("FileOperate.Open"));
}

private function fileSaveAsJSON():void {
	fileExport.url = fileWrite.url;
	if (fileExport.extension == null || fileExport.extension.toLowerCase() != "json") {
		fileExport.url += ".json";
	}
	fileExport.browseForSave(LocaleManager.getIns().getLangString("FileOperate.ExportJSON"));
}

private var solWriter:SOL;
private var amfWriter:AMF;

private function fileSave():void {
	var o:Object = {};
	var a:Array = _dataProvider.source;
	var fileName:String = a[0].name;

	if (CONFIG::debugging) {
		if (a[0].hasOwnProperty("children")) o = toObject(a[0].children, o);
	} else {
		try {
			if (a[0].hasOwnProperty("children")) o = toObject(a[0].children, o);
		} catch (e:Error) {
			AlertBox.show(e.message);
			return;
		}
	}

	// Display opening message
	updateTreedataProvider(new ArrayCollection([{name: LocaleManager.getIns().getLangString("Waiting.Saving")}]));

	if (isSOL) {
		solWriter = new SOL();
		solWriter.addEventListener(Event.COMPLETE, saveCompleteHandler, false, 0, true);
		if (CONFIG::debugging) {
			solWriter.serialize(systemManager, fileName, o, nVersion);
		} else {
			try {
				solWriter.serialize(systemManager, fileName, o, nVersion);
			} catch (e:Error) {
				AlertBox.show(e.message);
			}
		}
	} else {
		amfWriter = new AMF();
		amfWriter.addEventListener(Event.COMPLETE, saveCompleteHandler, false, 0, true);
		if (CONFIG::debugging) {
			amfWriter.serialize(systemManager, o, nVersion);
		} else {
			try {
				amfWriter.serialize(systemManager, o, nVersion);
			} catch (e:Error) {
				AlertBox.show(e.message);
			}
		}
	}
}

private function saveCompleteHandler(e:Event):void {
	if (solWriter) solWriter.removeEventListener(Event.COMPLETE, saveCompleteHandler);
	if (amfWriter) amfWriter.removeEventListener(Event.COMPLETE, saveCompleteHandler);

	var stream:FileStream = new FileStream();
	stream.open(fileWrite, FileMode.WRITE);
	if (isSOL) {
		stream.writeBytes(solWriter.rawData);
	} else {
		stream.writeBytes(amfWriter.rawData);
	}
	stream.close();

	solWriter = null;
	amfWriter = null;

	// Clear message
	updateTreedataProvider(new ArrayCollection([{name: LocaleManager.getIns().getLangString("Alert.FileSaveSuccess")}]));

	// Open the new file
	if (fileRead.hasEventListener(Event.SELECT)) fileRead.removeEventListener(Event.SELECT, openHandler);
	fileRead = fileWrite;
	setTimeout(openHandler, 500);
}

// Fix JSON parsing associative arrays
private function JSONHelper(key:String, value:*):* {
	if (!value) return value;
	var typeName:String = describeType(value).@name.toString();
	if (typeName == "Array") {
		var isAssociative:Boolean = false;
		var o:Object = {};
		for (var k:String in value) {
			if (k != 'length' && isNaN(Number(k))) {
				isAssociative = true;
				o[k] = value[k];
			}
		}
		if (isAssociative) return o;
	}
	return value;
}

private function saveJSONHandler(e:Event = null):void {
	var o:Object = {};
	var a:Array = _dataProvider.source;
	var fileName:String = a[0].name;

	if ((fileExport.extension == null || fileExport.extension.toLowerCase() != "json")) {
		fileExport.url += ".json";
	}

	if (CONFIG::debugging) {
		if (a[0].hasOwnProperty("children")) o = toObject(a[0].children, o);
	} else {
		try {
			if (a[0].hasOwnProperty("children")) o = toObject(a[0].children, o);
		} catch (err:Error) {
			AlertBox.show(err.message);
			return;
		}
	}
	try {
		var strJSON:String = JSON.stringify(o, JSONHelper);
		var stream:FileStream = new FileStream();
		stream.open(fileExport, FileMode.WRITE);
		stream.writeUTFBytes(strJSON);
		stream.close();
		AlertBox.show(LocaleManager.getIns().getLangString("Alert.FileExportSuccess"));
	} catch (e:Error) {
		AlertBox.show(LocaleManager.getIns().getLangString("Error.FileExportFail"));

	}
}

private function saveHandler(e:Event):void {
	// Force extension
	if (isSOL && (fileWrite.extension == null || fileWrite.extension.toLowerCase() != "sol")) {
		fileWrite.url += ".sol";
	} else if (!isSOL && (fileWrite.extension == null || fileWrite.extension.toLowerCase() != "amf")) {
		fileWrite.url += ".amf";
	}
	fileSave();
}

private function determineType(val:*):String {
	var type:String = typeof (val);

	if (type == "number") {
		if (nVersion == 3) {
			if (val % 1 == 0 && (val < int.MAX_VALUE && val > int.MIN_VALUE)) {
				//if(val is int) {
				//	return "Integer";
				//} else if(val is uint) {
				return "Integer";
			} else {
				return "Number";
			}
		} else {
			return "Number";
		}
	} else if (type == "object") {
		if (val == null) {
			return "Null";
		} else if (val is Array) {
			return "Array";
		} else if (val is Date) {
			return "Date";
		} else if (val is XMLDocument) {
			return "XMLDocument";
		} else if (val is ByteArray) {
			return "ByteArray";
		} else if (val is Vector.<int>) {
			return 'Vector.<int>';
		} else if (val is Vector.<uint>) {
			return 'Vector.<uint>';
		} else if (val is Vector.<Number>) {
			return 'Vector.<Number>';
		} else if (val is Vector.<Object>) {
			return 'Vector.<Object>';
		} else if (val is Object) {
			return "Object";
		}
	} else if (type == "boolean") {
		return "Boolean";
	} else if (type == "string") {
		if (val == "__unsupported") return "Unsupported";
		return "String";
	} else if (type == "xml") {
		return "XML";
	}

	return "Undefined";
}

/**
 * 压缩ByteArray
 * @param e
 */
private function compressByteArray(e:Event):void {
	var ba:ByteArray = dataTree.selectedItem.value as ByteArray;
	if (!ba || ba.length == 0) return;
	var compressMethod:String = compressMethodCombo.selectedItem.value;
	try {
		switch (compressMethod) {
			case "zlib":
				ba.compress(CompressionAlgorithm.ZLIB);
				break;
			case "deflate":
				ba.compress(CompressionAlgorithm.DEFLATE);
				break;
			case "lzma":
				try {
					var hasLZMA:Boolean = getDefinitionByName("flash.utils.CompressionAlgorithm").LZMA == "lzma";
				} catch (e:Error) {
					hasLZMA = false;
				}
				if (!hasLZMA) {
					AlertBox.show(LocaleManager.getIns().getLangString("Error.LZMANotSupport"));
					return;
				}
				ba.compress(CompressionAlgorithm["LZMA"]);
				break;
		}
	} catch (e:Error) {
		AlertBox.show(e.message);
		return;
	}
	displayByteArray();
}

/**
 * 解压ByteArray
 * @param e
 */
private function uncompressByteArray(e:Event):void {
	var ba:ByteArray = dataTree.selectedItem.value as ByteArray;
	if (!ba || ba.length == 0) return;
	var compressMethod:String = compressMethodCombo.selectedItem.value;
	try {
		switch (compressMethod) {
			case "zlib":
				ba.uncompress(CompressionAlgorithm.ZLIB);
				break;
			case "deflate":
				ba.uncompress(CompressionAlgorithm.DEFLATE);
				break;
			case "lzma":
				try {
					var hasLZMA:Boolean = getDefinitionByName("flash.utils.CompressionAlgorithm").LZMA == "lzma";
				} catch (e:Error) {
					hasLZMA = false;
				}
				if (!hasLZMA) {
					AlertBox.show(LocaleManager.getIns().getLangString("Error.LZMANotSupport"));
					return;
				}
				ba.uncompress(CompressionAlgorithm["LZMA"]);
				break;
		}
	} catch (e:Error) {
		AlertBox.show(e.message);
		return;
	}
	displayByteArray();
}

private function importExternalByteArray():void {
	if (!dataTree.selectedItem) {
		AlertBox.show(LocaleManager.getIns().getLangString("Error.NodeSelectionNeed"));
		return;
	}
	NativeFile.browseForFile(function (data:*):void {
		if (data is String) {
			var ba:ByteArray = new ByteArray();
			ba.readBytes(data);
			dataTree.selectedItem.value = ba;
		} else if (data is ByteArray) {
			dataTree.selectedItem.value = data;
		}else{
			AlertBox.show(LocaleManager.getIns().getLangString("TypeForm.ByteArray.ImportError"));
			return;
		}
		displayByteArray();
		AlertBox.show(LocaleManager.getIns().getLangString("TypeForm.ByteArray.ImportSuccess"));
	}, null, null, LocaleManager.getIns().getLangString("TypeForm.ByteArray.Import"));
}

private function base64Encode(e:Event, str:String):void {
	try {
		stringValueInput.text = Base64.encode(str);
	} catch (e:Error) {
		AlertBox.show(e.message);
	}
}

private function base64Decode(e:Event, str:String):void {
	try {
		stringValueInput.text = Base64.decode(str);
	} catch (e:Error) {
		AlertBox.show(e.message);

	}
}

private function uriEncode(e:Event, str:String):void {
	try {
		stringValueInput.text = encodeURIComponent(str);
	} catch (e:Error) {
		AlertBox.show(e.message);

	}
}

private function uriDecode(e:Event, str:String):void {
	try {
		stringValueInput.text = decodeURIComponent(str);
	} catch (e:Error) {
		AlertBox.show(e.message);

	}
}

private function displayByteArray():void {
	var ba:ByteArray = dataTree.selectedItem.value as ByteArray;
	if (!ba || ba.length == 0) {
		ba = new ByteArray();
		ba[1] = 1;
		byteBitmap.loadFromBytes(ba);
		byteText.text = "";
		return;
	}
	ba.position = 0;
	var dispMethod:String = bytesDispCombo.selectedItem.value;
	switch (dispMethod) {
		case "bitmap":
			byteBitmap.loadFromBytes(ba);
			break;
		case "utf8":
			byteText.text = ba.readMultiByte(ba.bytesAvailable, "utf-8");
			break;
		case "utf16":
			byteText.text = ba.readMultiByte(ba.bytesAvailable, "utf-16");
			break;
		case "gb2312":
			byteText.text = ba.readMultiByte(ba.bytesAvailable, "gb2312");
			break;
		case "base64":
			byteText.text = Base64.encodeByteArray(ba);
			break;
		case "rawHex":
			byteText.text = byteArray2String(ba);
			break;
		case "object":
			try {
				byteText.text = JSON.stringify(ba.readObject());
			} catch (err:Error) {
				AlertBox.show(err.message);
				byteText.text = "";
			}
			break;
	}
}

private function compile2bin(confirmFlag:uint):void {
	if (!(Boolean(confirmFlag & AlertBox.YES) || Boolean(confirmFlag & AlertBox.OK))) {
		return;
	}
	var dispMethod:String = bytesDispCombo.selectedItem.value;
	var ba:ByteArray;
	switch (dispMethod) {
		case "utf8":
			ba = new ByteArray();
			ba.writeMultiByte(byteText.text, "utf-8");
			dataTree.selectedItem.value = ba;
			break;
		case "utf16":
			ba = new ByteArray();
			ba.writeMultiByte(byteText.text, "utf-16");
			dataTree.selectedItem.value = ba;
			break;
		case "gb2312":
			ba = new ByteArray();
			ba.writeMultiByte(byteText.text, "gb2312");
			dataTree.selectedItem.value = ba;
			break;
		case "base64":
			dataTree.selectedItem.value = Base64.decodeToByteArray(byteText.text);
			break;
		case "rawHex":
			dataTree.selectedItem.value = string2ByteArray(byteText.text);
			break;
		case "object":
			ba = new ByteArray();
			try {
				ba.writeObject(JSON.parse(byteText.text));
			} catch (err:Error) {
				AlertBox.show(err.message);
			}
			dataTree.selectedItem.value = ba;
			break;
		case "bitmap":
		default:
			break;
	}
	AlertBox.show(LocaleManager.getIns().getLangString("TypeForm.ByteArray.CompileFinish"), '', AlertBox.OK)
}

private function string2ByteArray(str:String):ByteArray {
	var arrBytes:Array = str.split(", ");
	var ba:ByteArray = new ByteArray();
	var l2:uint = arrBytes.length;
	for (var j:int = 0; j < l2; ++j) {
		ba[j] = Number("0x" + arrBytes[j]);
	}
	ba.position = 0;
	return ba;
}

private function byteArray2String(ba:ByteArray):String {
	var str:String = "";
	for (var i:int = 0; i < ba.length; i++) {
		var byte:String = Number(ba[i]).toString(16).toUpperCase();
		if (byte.length < 2) byte = "0" + byte;
		str += byte + ", ";
	}
	str = str.substring(0, (str.length - 2));
	return str;
}

private function treeTip(item:Object):String {
	return item.type;
}

private function treeIcon(item:Object):Class {
	var iconClass:Class;
	var type:String = item.type;
	if (type && type.indexOf('Vector') != -1) type = 'Vector';
	switch (type) {
		case "Boolean":
			iconClass = booleanIcon;
			break;
		case "ByteArray":
			iconClass = bytearrayIcon;
			break;
		case "XMLDocument":
		case "XML":
			iconClass = xmlIcon;
			break;
		case "String":
			iconClass = stringIcon;
			break;
		case "Date":
			iconClass = dateIcon;
			break;
		case "Integer":
			iconClass = intIcon;
			break;
		case "Vector" :
			iconClass = vectorIcon;
			break;
		case "Null":
		case "Undefined":
		case "Unsupported":
			iconClass = undefinedIcon;
			break;
		case "Object":
			iconClass = objectIcon;
			break;
		case "Array":
			iconClass = arrayIcon;
			break;
		case "Number":
			iconClass = numberIcon;
			break;
		default:
			iconClass = null;
	}
	return iconClass;
}

private function treeLabel(item:Object):String {
	var strName:String = item.name || LocaleManager.getIns().getLangString("Error.NoOpenedFile");
	return strName;
}

private function treeValueChanged(e:Event, type:String = "invalid", value:* = null, hour:* = null, min:* = null, sec:* = null):void {
	if (hour != null) {
		var d:Date = value as Date;
		d.hours = hour;
		d.minutes = min;
		d.seconds = sec;
		dataTree.selectedItem.value = d;
	} else {
		dataTree.selectedItem.value = value;
	}

	if (type != 'invalid') {
		var isNewType:Boolean = (dataTree.selectedItem.type != type);
		dataTree.selectedItem.type = type;

		// update icon
		if (isNewType) {
			//validate Object and Array data
			if (type == "Object" || type == "Array") {
				dataTree.selectedItem.children = [];
				dataTree.selectedItem.traits = {count: 0, members: [], type: type};
			}
			dataTree.iconField = "icon";
			treeChanged();
		}
	}
}

private function treeDoubleClick(e:ListEvent):void {
	isStartEdit = true;
	dataTree.editedItemPosition = {columnIndex: 0, rowIndex: e.rowIndex};
}

private function treeKeyDown(e:KeyboardEvent):void {
	if (e.charCode == 127) { // Delete
		onClickRemove();
	}
}

private function treeEditBegin(e:ListEvent):void {
	if (!isStartEdit) {
		e.preventDefault();
		e.stopImmediatePropagation();
		e.stopPropagation();
		if (lastSelected) dataTree.selectedItem = lastSelected;
	}

	var item:TreeItemRenderer = e.itemRenderer as TreeItemRenderer;
	var listData:TreeListData = item.listData as TreeListData;
	// Check if has icon or not
	if (listData.icon) {
		dataTree.editorXOffset = 30;
	} else {
		dataTree.editorXOffset = 15;
	}
}

private function treeEditBeginning(e:ListEvent):void {
	lastSelected = dataTree.selectedItem;
	e.preventDefault();
}

private function treeEditEnd(e:ListEvent):void {
	isStartEdit = false;

	// Disable copying data back to the control
	e.preventDefault();

	// Get new value from editor
	var edited:TreeItemRenderer = dataTree.editedItemRenderer as TreeItemRenderer;
	edited.data.name = mx.controls.TextInput(dataTree.itemEditorInstance).text;

	// Update item label
	var listData:TreeListData = edited.listData as TreeListData;
	listData.label = edited.data.name;
	edited.invalidateProperties();

	// Close the cell editor
	dataTree.destroyItemEditor();

	// Notify the list control to update its display
	dataTree.dataProvider.notifyItemUpdate(edited);
}

private function treeChanged(e:Event = null):void {
	var selectedNode:Object = e ? Tree(e.target).selectedItem : dataTree.selectedItem;
	if (selectedNode.type != null) {
		showInspector = true;

		switch (selectedNode.type) {
			case "Integer":
				selectedNode.value = int(selectedNode.value);
			case "Number":
				numberValueInput.text = String(selectedNode.value);
				vsType.selectedChild = NumberType;
				//ddNumberType.selectedIndex = ArrayUtil.getItemIndex(selectedNode.type, arrDataTypes);
				break;
			case "Boolean":
				if (selectedNode.value) {
					radTrue.selected = true;
				} else {
					radFalse.selected = true;
				}
				vsType.selectedChild = BooleanType;
				//ddBooleanType.selectedIndex = 1;
				break;
			case "ByteArray":
				vsType.selectedChild = ByteArrayType;
				//judge data type of selectedNode.value
				var ba:ByteArray = selectedNode.value as ByteArray;
				if (!ba) {
					displayByteArray();
					break;
				}
				if ((ba[1] == "P".charCodeAt() && ba[2] == "N".charCodeAt() && ba[3] == "G".charCodeAt()) ||
						ba[6] == "J".charCodeAt() && ba[7] == "F".charCodeAt() && ba[8] == "I".charCodeAt() && ba[9] == "F".charCodeAt()) {
					bytesDispCombo.selectedIndex = 4;
				} else {
					bytesDispCombo.selectedIndex = 0;
				}
				displayByteArray();
				break;
			case "String":
			case "XML":
			case "XMLDocument":
				stringValueInput.text = String(selectedNode.value);
				vsType.selectedChild = StringType;
				//ddStringType.selectedIndex = ArrayUtil.getItemIndex(selectedNode.type, arrDataTypes);
				break;
			case "Date":
				if (selectedNode.value === null) selectedNode.value = new Date();
				var tempDate:Date = selectedNode.value as Date;
				dateDF.selectedDate = tempDate;
				txtHour.text = String(tempDate.hours);
				txtMin.text = String(tempDate.minutes);
				txtSec.text = String(tempDate.seconds);
				vsType.selectedChild = DateType;
				break;
			case "Null":
			case "Undefined":
				vsType.selectedChild = EmptyType;
//				ddEmptyType.selectedIndex = ArrayUtil.getItemIndex(selectedNode.type, arrDataTypes);
				break;
			case "Array":
				vsType.selectedChild = ArrayType;
				break;
			case "Object":
				vsType.selectedChild = ObjectType;
				break;
			default:
				vsType.selectedChild = InfoType;
				break;
		}
	}
}