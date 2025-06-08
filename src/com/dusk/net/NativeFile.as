package com.dusk.net
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.FileListEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;

	//当程序处在Air下才可调用
	public class NativeFile
	{
		
		/**
		 * 获取应用文件夹根目录
		 * @return
		 */
		public static function getAppRoot():String
		{
			return File.applicationDirectory.nativePath;
		}
		
		/**
		 * 打开对话框并选取单文件
		 * @param	completeCB 成功回调
		 * @param	cancelCB 取消回调
		 * @param	filters 文件过滤
		 * @param	title 对话标题
		 * @param	defaultPath 默认路径
		 */
		public static function browseForFile(completeCB:Function = null, cancelCB:Function = null, filters:Array = null, title:* = null, defaultPath:String = null):void
		{
			var f:File = new File();
			if (defaultPath)
			{
				f.nativePath = defaultPath;
			}
			var onCom:Function = function(param1:Event):void
			{
				if (Boolean(completeCB))
				{
					completeCB(f.data);
				}
				f.removeEventListener(Event.COMPLETE, onCom);
			};
			var onSel:Function = function(param1:Event):void
			{
				f.load();
				f.removeEventListener(Event.SELECT, onSel);
				f.removeEventListener(Event.CANCEL, onCan);
			};
			var onCan:Function = function(param1:Event):void
			{
				if (Boolean(cancelCB))
				{
					cancelCB();
				}
				f.removeEventListener(Event.COMPLETE, onCom);
				f.removeEventListener(Event.SELECT, onSel);
				f.removeEventListener(Event.CANCEL, onCan);
			};
			f.addEventListener(Event.COMPLETE, onCom);
			f.addEventListener(Event.SELECT, onSel);
			f.addEventListener(Event.CANCEL, onCan);
			f.browseForOpen(title, filters);
		}
		
		/**
		 * 打开文件夹对话框并选取文件
		 * @param	completeCB
		 * @param	cancelCB
		 * @param	filters
		 * @param	title = null
		 * @param	defaultPath
		 */
		public static function browseForFiles(completeCB:Function = null, cancelCB:Function = null, filters:Array = null, title:String = null, defaultPath:String = null):void
		{
			var f:File = new File();
			if (defaultPath) f.nativePath = defaultPath;
			var onSel:Function = function(e:FileListEvent):void
			{
				if (completeCB) completeCB(e.files);
				f.removeEventListener(FileListEvent.SELECT_MULTIPLE, onSel);
				f.removeEventListener(Event.CANCEL, onCan);
			}
			var onCan:Function = function(e:Event):void
			{
				if (cancelCB) cancelCB();
				f.removeEventListener(FileListEvent.SELECT_MULTIPLE, onSel);
				f.removeEventListener(Event.CANCEL, onCan);
			}
			f.addEventListener(FileListEvent.SELECT_MULTIPLE, onSel);
			f.addEventListener(Event.CANCEL, onCan);
			f.browseForOpenMultiple(title, filters);
		}
	}
}