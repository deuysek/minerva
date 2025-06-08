package com.coursevector.minerva 
{
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.SharedObject;
	/**
	 * ...
	 * @author Duskeye
	 */
	public class LocaleManager 
	{
		
		public function LocaleManager() 
		{
			super();
		}
		
		public static var DEFAULT_LOCALE:String = "zh_CN";
		
		private static var _ins:LocaleManager;
		
		private static const LOCALE_FOLDER:String = "assets/lang/";
		
		public static function getIns():LocaleManager
		{
			return _ins ||= new LocaleManager;
		}
		
		private var _curLocale:String;
		
		private var _locales:Object;
		
		private var _init:Boolean = false;
		
		public function init():void
		{
			if (_init) return;
			_init = true;
			
			_locales = {};
			var f:File = File.applicationDirectory.resolvePath(LOCALE_FOLDER);
			if (!f.exists) throw new ArgumentError("Folder not found");
			var fileList:Array = f.getDirectoryListing();
			if (fileList.length == 0) throw new ArgumentError("No locale found");
			for each(var singleFile:File in fileList)
			{
				var localeFile:File = f.resolvePath(singleFile.name);
				if (!localeFile.exists) throw new ArgumentError("File not found");
				var fs:FileStream = new FileStream();
				fs.open(localeFile, FileMode.READ);
				var str:String = fs.readUTFBytes(fs.bytesAvailable);
				fs.close();
				var fileName:String = localeFile.name;
				if (localeFile.extension) fileName = fileName.replace("." + localeFile.extension, "");
				try{
					_locales[fileName] = JSON.parse(str);
				}catch(err:Error){
					
				}
			}
			var so:SharedObject = SharedObject.getLocal("settings");
			_curLocale = so.data.locale || DEFAULT_LOCALE;
		}
		
		public function changeLocale(locale:String):String
		{
			_curLocale = locale;
			var so:SharedObject = SharedObject.getLocal("settings");
			so.data.locale = locale;
			return so.flush();
		}
		
		public function getAllLocales():Array {
			var arr:Array = [];
			for (var key:String in _locales)
			{
				arr.push(key);
			}
			return arr;
		}
		
		public function getLangPack():Object
		{
			if (!_init) init();
			return _locales[_curLocale];
		}
		
	}

}