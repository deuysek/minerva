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
		public static function exists(path:String):Boolean
		{
			return File.documentsDirectory.resolvePath(path).exists;
		}
		
		public static function isFile(path:String):Boolean
		{
			return !File.documentsDirectory.resolvePath(path).isDirectory;
		}
		
		public static function isDirectory(path:String):Boolean
		{
			return File.documentsDirectory.resolvePath(path).isDirectory;
		}

		/**
		 * 向文件中覆盖写入
		 * @param	content 写入内容，可以为ByteArray或者String
		 * @param	path 文件路径
		 * @return
		 */
		public static function write(content:*, path:String):Boolean
		{
			var file:File = File.documentsDirectory.resolvePath(path);
			var fileStream:FileStream = new FileStream();
			try
			{
				fileStream.open(file, FileMode.WRITE);
				if (content is String)
				{
					fileStream.writeUTFBytes(content);
				}
				else
				{
					fileStream.writeBytes(content);
				}
				fileStream.close();
				return true;
			} catch (e:Error)
			{
				fileStream.close();
				return false;
			}
		}
		
		/**
		 * 向文件中追加内容
		 * @param	content 追加内容，可以为ByteArray或者String
		 * @param	path 文件路径
		 * @return
		 */
		public static function append(content:*, path:String):Boolean
		{
			var file:File = File.documentsDirectory.resolvePath(path);
			var fileStream:FileStream = new FileStream();
			try
			{
				fileStream.open(file, FileMode.APPEND);
				if (content is String)
				{
					fileStream.writeUTFBytes(content);
				}
				else
				{
					fileStream.writeBytes(content);
				}
				fileStream.close();
				return true;
			} catch (e:Error)
			{
				fileStream.close();
				return false;
			}
		}

		/**
		 * 读取文件
		 * @param path 文件路径
		 * @param readType 读取类型，可选值为"text"和"binary"
		 * @return 读取结果
		 */
		public static function read(path:String, readType:String = "text"):*
		{
			if (!exists(path) || isDirectory(path))
			{
				switch (readType)
				{
					case "text":
						return "";
					case "binary":
						return new ByteArray();
				}
			}
			var file:File = File.documentsDirectory.resolvePath(path);
			var fileStream:FileStream = new FileStream();
			fileStream.open(file, FileMode.READ);
			if (readType == "binary")
			{
				var bytes:ByteArray = new ByteArray();
				fileStream.readBytes(bytes);
				fileStream.close();
				return bytes;
			}
			else if (readType == "text")
			{
				var str:String = fileStream.readUTFBytes(fileStream.bytesAvailable);
				fileStream.close();
				return str;
			}
			else
			{
				fileStream.close();
				return null;
			}
		}
		

		/**
		 * 读取应用文件夹文件
		 * @param path 文件路径
		 * @param readType 读取类型，可选值为"text"和"binary"
		 * @return 读取结果
		 */
		public static function readAppFolderFile(path:String, readType:String = "text"):*
		{
			return read(getAppFolderFileUrl(path), readType);
		}
		
		
		/**
		 * 向应用文件夹文件中追加内容
		 * @param	content 追加内容，可以为ByteArray或者String
		 * @param	path 文件路径
		 * @return
		 */
		public static function appendAppFolderFile(content:*, path:String):Boolean
		{
			return append(content, getAppFolderFileUrl(path));
		}

		/**
		 * 向应用文件夹文件中覆盖写入
		 * @param	content 写入内容，可以为ByteArray或者String
		 * @param	path 文件路径
		 * @return
		 */
		public static function writeAppFolderFile(content:*, path:String):Boolean
		{
			return write(content, getAppFolderFileUrl(path));
		}
		
		/**
		 * 写入临时文件
		 * @param	data
		 * @param	fileName
		 * @return
		 */
		public static function writeToTempFile(data:*, fileName:String = ""):File
		{
			var file:File;
			if (fileName)
			{
				file = new File(File.cacheDirectory.nativePath + "\\" + fileName);
				write(data, file.nativePath);
				return file;
			}
			file = File.createTempFile();
			write(data, file.nativePath);
			return file;
		}
		
		/**
		 * 创建文件夹，如果已经存在则返回
		 * @param	path
		 */
		public static function createFolder(path:String):void
		{
			var file:File = new File(path);
			if (file.exists) return;
			file.createDirectory();
		}
		
		/**
		 * 获取应用文件夹根目录
		 * @return
		 */
		public static function getAppRoot():String
		{
			return File.applicationDirectory.nativePath;
		}

		public static function getAppFolderFileUrl(path:String):String
		{
			path = getAppRoot() + "/" + path;
			return format(path);
		}
		
		/**
		 * 移动目标
		 * @param	sourceDir 源地址
		 * @param	targetDir 目标地址
		 * @param	overwrite 是否创建不存在的文件夹
		 */
		public static function move(sourceDir:String, targetDir:String, overwrite:Boolean = true):void
		{
			new File(sourceDir).moveTo(new File(targetDir), overwrite);
		}

		
		/**
		 * 复制目标
		 * @param	sourceDir 源地址
		 * @param	targetDir 目标地址
		 * @param	overwrite 是否创建不存在的文件夹
		 */
		public static function copy(sourceDir:String, targetDir:String, overwrite:Boolean = true):void
		{
			new File(sourceDir).copyTo(new File(targetDir), overwrite);
		}
		
		/**
		 * 删除（无论是文件还是文件夹）
		 * @param	path
		 */
		public static function remove(path:String):void
		{
			del(path);
			rd(path);
		}
		
		/**
		 * 删除文件
		 * @param	path
		 * @return 是否删除成功
		 */
		public static function del(path:String):Boolean
		{
			if (!exists(path)) return true;
			try
			{
				new File(path).deleteFile();
				return true;
			}
			catch (e:Error)
			{
				trace(e);
				return false;
			}
		}
		
		public static function delAsync(path:String,comCb:Function = null,failCb:Function = null):void
		{
			if (!exists(path))
			{
				if (comCb) comCb();
				return;
			}
			try
			{
				var file:File = new File(path);
				file.deleteFileAsync();
				file.addEventListener(Event.COMPLETE, function(evt){
					if (comCb) comCb();
					if (comCb) file.removeEventListener(Event.COMPLETE, comCb);
					if (failCb) file.removeEventListener(IOErrorEvent.IO_ERROR, failCb);
				});
				file.addEventListener(IOErrorEvent.IO_ERROR, function(evt){
					if (failCb) failCb();
					if (comCb) file.removeEventListener(Event.COMPLETE, comCb);
					if (failCb) file.removeEventListener(IOErrorEvent.IO_ERROR, failCb);
				});
			}
			catch (e:Error)
			{
				trace(e);
			}
		}
		
		/**
		 * 删除目录
		 * @param	path
		 * @return 是否删除成功
		 */
		public static function rd(path:String):Boolean
		{
			if (!exists(path)) return true;
			try
			{
				new File(path).deleteDirectory(true);
				return true;
			}
			catch (e:Error)
			{
				trace(e);
				return false;
			}
		}
		
		public static function rdAsync(path:String,comCb:Function = null,failCb:Function = null):void
		{
			if (!exists(path))
			{
				if (comCb) comCb();
				return;
			}
			try
			{
				var file:File = new File(path);
				file.deleteDirectoryAsync(true);
				file.addEventListener(Event.COMPLETE, function(evt){
					if (comCb) comCb();
					if (comCb) file.removeEventListener(Event.COMPLETE, comCb);
					if (failCb) file.removeEventListener(IOErrorEvent.IO_ERROR, failCb);
				});
				file.addEventListener(IOErrorEvent.IO_ERROR, function(evt){
					if (failCb) failCb();
					if (comCb) file.removeEventListener(Event.COMPLETE, comCb);
					if (failCb) file.removeEventListener(IOErrorEvent.IO_ERROR, failCb);
				});
			}
			catch (e:Error)
			{
				trace(e);
			}
		}
		
		/**
		 * 标准化路径
		 * @param	path 目标路径
		 * @param	splitter 路径分隔符，默认 "/"
		 * @return
		 */
		public static function format(path:String, splitter:String = "/"):String
		{
			try
			{
				var file:File = new File(path);
				file.canonicalize();
				return file.nativePath.replace(/\\/g,splitter);
			}
			catch (e:Error)
			{
				trace(e);
				return "";
			}
		}
		
		/**
		 * 启动目标程序
		 * @param	path 程序地址
		 * @param	...args 附带参数
		 * @return
		 */
		public static function start(path:String, ...args):NativeProcess
		{
			//noinspection SpellCheckingInspection
			if (!NativeProcess.isSupported) return null;
			var NPSI:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			NPSI.executable = File.documentsDirectory.resolvePath(path);
			NPSI.arguments = new Vector.<String>;
			if (args[0] is Array) args = (args[0] as Array).slice();
			while (args.length)
			{
				(NPSI.arguments as Vector.<String>).push(args.shift());
			}
			trace(NPSI.executable.nativePath)
			var NP:NativeProcess = new NativeProcess();
			NP.start(NPSI);
			return NP;
		}

		/**
		 * 获取目标文件在指定目录的深度，最多到100层
		 * @param curFile 当前文件或者文件夹
		 * @param targetDir 目标目录（不能说文件）
		 * @return 返回1则表示是该文件夹内的子文件或者子文件夹，以此类推
		 * @return 若返回-1则表示不是该文件夹内的子文件或者子文件夹或者层数超出最大限制100层
		 * @example
		 * file1 = new File("test/");
		 * file2 = new File("test/test");
		 * file3 = new File("test/test/test.txt");
		 * file4 = new File("exception/");
		 * trace(getDepthFileToTarget(file2,file1));
		 * //输出：1
		 * trace(getDepthFileToTarget(file3,file1));
		 * //输出：2
		 * trace(getDepthFileToTarget(file4,file1));
		 * //输出：-1
		 */
		public static function getFileDepthInTargetDir(curFile:File, targetDir:File):int
		{
			if(!targetDir.isDirectory) return -1;
			for(var i:int = 1; i <= 100; i++)
			{
				if(curFile.parent.nativePath == targetDir.nativePath)
				{
					return i;
				}
			}
			return -1;
		}

		/**
		 * 获取文件夹下所有文件夹，不包括文件
		 * @param folder 目标目录
		 * @return 文件夹列表
		 */
		public static function getAllFoldersInFolder(folder:File):Vector.<File>
		{
			var folderList:Vector.<File> = new Vector.<File>();
			if (!folder.isDirectory) return new Vector.<File>();
			
			for each(var f:File in folder.getDirectoryListing())
			{
				if (f.isDirectory)
				{
					folderList.push(f);
				}
			}
			return folderList;
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
					cancelCB;
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
		public static function browseForFiles(completeCB:Function = null, cancelCB:Function = null, filters:Array = null, title = null, defaultPath:String = null):void
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
				if (cancelCB) cancelCB;
				f.removeEventListener(FileListEvent.SELECT_MULTIPLE, onSel);
				f.removeEventListener(Event.CANCEL, onCan);
			}
			f.addEventListener(FileListEvent.SELECT_MULTIPLE, onSel);
			f.addEventListener(Event.CANCEL, onCan);
			f.browseForOpenMultiple(title, filters);
		}

		/**
		 * 获取文件夹下所有文件，不包括文件夹
		 * @param folder 目标目录
		 * @param depth 搜索深度
		 * @return 文件列表
		 */
		public static function getAllFilesInFolder(folder:File, depth:int = 999):Vector.<File>
		{
			var folderQueue:Vector.<File> = new Vector.<File>();
			var fileList:Vector.<File> = new Vector.<File>();
			if (!folder.isDirectory) return new Vector.<File>();
			var folderTmp:File = new File(folder.nativePath);
			folderQueue.push(folderTmp);
			while (!folderQueue.length == 0)
			{
				folderTmp = folderQueue.shift();
				if (!folderTmp.exists || folderTmp.getDirectoryListing().isEmpty()) continue;
				folderTmp.getDirectoryListing().forEach(function (item:File, a:*, b:*):void
				{
					if (item.isDirectory)
					{
						if (getFileDepthInTargetDir(item,folder) < depth)
						{
							folderQueue.push(item);
						}
					}
					else
					{
						fileList.push(item);
					}
				});
			}
			return fileList;
		}
	}
}