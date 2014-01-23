package
{
	import com.greensock.TweenLite;
	
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.display.StageDisplayState;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.media.SoundTransform;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.system.Capabilities;
	import flash.utils.*;
	
	import mx.utils.StringUtil;

	
	public class MonitorView extends Sprite
	{
		// static const
		private static const MAX_INT_VALUE:int = int.MAX_VALUE;
		private static const SCREEN_WIDTH:Number = Capabilities.screenResolutionX;
		private static const SCREEN_HEIGHT:Number = Capabilities.screenResolutionY;
		
		//interface
		private var _bottomBar:BottomBar;
		private var _fourUI:FourUI;
		private var _nineUI:NineUI;
		
		//variables
		private var _list:Array = [];
		private var _client:Object = new Object();
		
		// total page count
		private var _totalPageNumOfFour:int = 0;
		private var _totalPageNumOfNine:int = 0;
		
		//current page number
		private var _curPageNumOfFour:int = 1;
		private var _curPageNumOfNine:int = 1;
		
		// live count
		private var _curPageMinLiveContainerIndex:int = 0;
		private var _curPageLiveContainerIndex:int = 0;
		private var _curPageMaxLiveContainerIndex:int = 0;
		
		private var _curContainerIndex:int = 0;
		private var _curContainerVideoIndex:int = 0;
		private var _curContainerVideoCount:int = 0;
		
		private var _curPageMinIndex:int = 0;
		private var _curPageMaxIndex:int = 0;
		
		private var _curPageStartIndex:int = 0;
		private var _curPageEndIndex:int = 0;
		
		private var _isFourScreenInterface:Boolean = true;
		private var _playIntervalTime:int = 30;
		
		private var _curPlayerX:Number = 0;
		private var _curPlayerY:Number = 0;
		
		//interval
		private var _lockMouseInterval:Number = 0;  
		private var _closeTipInterval:Number;
		private var _closeTipLock:Boolean = false;
		private var _hideTimeSettingInterval:Number;
		private var _hideTimeSettingLock:Boolean = false;
		
		//timer
		private var _loadTimer:Timer = new Timer(1);
		private var _loadTimerLock:Boolean = false;
		private var _loopTimer:Timer = new Timer(_playIntervalTime * 1000); 
		private var _updateVideoTimeTimer:Timer = new Timer(1000);
		private var _hasLoopTimer:Boolean = false;
	
		
		//load live data
		private var _liveCount:int=0; 
		private var _liveData:Array=[];
		private var _liveRequest:URLRequest;
		private var _liveLoader:URLLoader; 
		private var _roomCount:int=0;
		
		//container
		private var _nsContainer:Vector.<NetStream>;
		private var _ncContainer:Vector.<NetConnection>;
		private var _videoBox:Vector.<Video>;
		private var _videoBoxContainer:Vector.<Sprite>;
		private var _videoContainer:Vector.<Sprite>;
		private var _curVideoContainer:Sprite;
		private var _playerBGContainer:Vector.<MovieClip>;
		private var _curVideoBox:Sprite;
		
		public function MonitorView()
		{
			init();
		}
		
		/**
		 *
		 * 界面及元件说明：
		 * <1> BottomBar : 底部控制栏
		 *     底部控制栏由：changeScreenBtn(屏幕切换按钮)、playMethod(播放模式切换按钮)、 timeSettingMC(轮播时间设定控件)、
		 *     gobackBtn(向前翻页按钮)、gofrontBtn(向后翻页按钮)、pageNumberTxt(页码显示文本框)、timeTipMC(时间设定提示文本)、
		 *     backErrorTip(向后翻页提示文本框)、fullscreenBtn(全屏按钮)、quitFullscreenBtn(退出全屏按钮)等组成；
		 *
		 *  <2> FourUI : 四画面分屏界面
		 *     四分屏界面由四个MovieClip组成，分别是playerUI1、playerUI2、playerUI3、playerUI4。每个playerUI为一个四帧的动画，
		 *     每一帧内容分别对应一个两帧的MovieClip。四帧对应的MovieClip分别为：Four_OneUI、Four_TwoUI、Four_ThreeUI、Four_FourUI。
		 *     其中Four_OneUI对应的两帧分别对应单个屏幕情况下两种大小的界面(正常模式、放大模式)，其他类似；
		 * 
		 * <3> NineUI : 九画面分屏界面
		 *     九分屏对应的组成元件参考四分屏界面
		 * 
		 */		
		private function init():void
		{
			initInterface();
			initPlayerBGContainer();
			loadLiveData();
			addListener();
		}
		
		/**
		 *
		 * 界面元件初始化：
		 * 隐藏前后翻页按钮、轮播时间设定按钮 
		 * 
		 */		
		private function initInterface():void
		{
			
			_bottomBar = new BottomBar();
			_bottomBar.x = 0;
			_bottomBar.y = 585;
			this.addChild(_bottomBar);
			_bottomBar.gobackBtn.visible = false;
			_bottomBar.gofrontBtn.visible = false;
			_bottomBar.timeSettingMC.visible = false;
			
			_fourUI = new FourUI();
			_fourUI.x = 0;
			_fourUI.y = 0;
			this.addChild(_fourUI);
		}
		
		// get live netstream information
		private function loadLiveData():void
		{
			_liveRequest = new URLRequest();
			_liveRequest.url = LiveModel.LIVE_URL; 
			_liveLoader = new URLLoader();
			_liveLoader.load(_liveRequest);
			_liveLoader.addEventListener(Event.COMPLETE, onLiveDataLoadComplete);
			_liveLoader.addEventListener(IOErrorEvent.IO_ERROR, onLiveDataLoadIOError);
			_liveLoader.addEventListener(ProgressEvent.PROGRESS, onLiveDataLoadProgress);
		}
		
		protected function onLiveDataLoadProgress(event:ProgressEvent):void
		{
			trace ("加载进度：" + (event.bytesLoaded / event.bytesTotal) * 100 + "%");
		}
		
		protected function onLiveDataLoadIOError(event:IOErrorEvent):void
		{
			trace ("load xml Error:" + event);
		}
		
		/**
		 * 
		 * @param event
		 * 解析数据，创建初始界面
		 *  
		 */		
		protected function onLiveDataLoadComplete(event:Event):void
		{
			parseXML(XML(_liveLoader.data));
			createMainInterface();  
		}
		
		// parse live xml
		protected function parseXML(xml:XML):void
		{
			var data:Array = new Array();
			for each (var lives:XML in xml.lives)
			{
				var vo:LiveDataVO = new LiveDataVO();
				vo.liveID = lives.@id.toString();
				vo.liveName = lives.@name.toString();
				vo.liveVO = new Array();
				for( var i:int=0; i<lives.children().length();i++) 
				{
					var lv:LiveVO = new LiveVO();
					lv.liveSDURL =  lives.live[i].@SD.toString();
					lv.liveHDURL = lives.live[i].@HD.toString();  
					lv.liveChannel = lives.live[i].@channel.toString(); 
					vo.liveVO.push(lv);
				}
				this._liveCount += lives.children().length();
				data.push(vo);
			}
			this._liveData = data;
			this._roomCount = data.length;
		}
		
		private function createMainInterface():void
		{
			//初始化容器
			_nsContainer = new Vector.<NetStream>(_liveCount);
			_ncContainer = new Vector.<NetConnection>(_liveCount);
			_videoBox = new Vector.<Video>(_liveCount);
			_videoBoxContainer = new Vector.<Sprite>(_liveCount);
			_videoContainer = new Vector.<Sprite>();
			
			//初始化相关索引
			_curPageMinIndex = 0;
			_curPageStartIndex = 0;
			_curPageNumOfFour = 1;
			_curPageNumOfNine = 1;
			
			//获取当前页最大索引
			getCurPageMaxIndex();
			_curPageEndIndex = _curPageMaxIndex;
			this._isFourScreenInterface = true;
			
			//初始化直播项索引
			this._curPageMinLiveContainerIndex = getCurPageMinLiveContainerIndex();
			this._curPageLiveContainerIndex = _curPageMinLiveContainerIndex;
			this._curPageMaxLiveContainerIndex = getCurPageMaxLiveContainerIndex();
			
			this._curContainerVideoIndex = 0;
			this._curContainerVideoCount = this._liveData[_curPageMinLiveContainerIndex].liveVO.length;
			
			//初始化页码
			figureOutTotalPageNum();
			
			//循环添加视频界面
			_loadTimer.start();
			_loadTimer.addEventListener(TimerEvent.TIMER, onLoadTimer);
			
			//更新当前时间
			_updateVideoTimeTimer.start();
			_updateVideoTimeTimer.addEventListener(TimerEvent.TIMER, onUpdateVideoTimeTimer);
		}
		
		/**
		 * 
		 * @param event
		 * 切换屏幕分屏，翻页操作前先停止时间更新
		 * 
		 */		
		private function onUpdateVideoTimeTimer(event:TimerEvent):void
		{
			if (this._isFourScreenInterface)
			{
				for (var i:int=0; i<4;i++)
				{
					var frame:int = (this._fourUI.getChildAt(i) as MovieClip).currentFrame;
					var mc:MovieClip = this._fourUI.getChildAt(i) as MovieClip;
					switch (frame)
					{
						case 1:
							mc.Four_OneUI.videoTime.text = TimeUtils.dateToTimeFomat();
							break;
						case 2:
							mc.Four_TwoUI.videoTime.text = TimeUtils.dateToTimeFomat();
							break;
						case 3:
							mc.Four_ThreeUI.videoTime.text = TimeUtils.dateToTimeFomat();
							break;
						case 4:
							mc.Four_FourUI.videoTime.text = TimeUtils.dateToTimeFomat();
							break;
						default:
							break;
					}
				}
			}
			else
			{
				for (var j:int=0; j<9;j++)
				{
					var frame2:int = (this._nineUI.getChildAt(j) as MovieClip).currentFrame;
					var mc2:MovieClip = this._nineUI.getChildAt(j) as MovieClip;
					switch (frame2)
					{
						case 1:
							mc2.Nine_OneUI.videoTime.text = TimeUtils.dateToTimeFomat();
							break;
						case 2:
							mc2.Nine_TwoUI.videoTime.text = TimeUtils.dateToTimeFomat();
							break;
						case 3:
							mc2.Nine_ThreeUI.videoTime.text = TimeUtils.dateToTimeFomat();
							break;
						case 4:
							mc2.Nine_FourUI.videoTime.text = TimeUtils.dateToTimeFomat();
							break;
						default:
							break;
					}
				}
			}
		}
		
		// initialize player bg container
		private function initPlayerBGContainer():void
		{
			_playerBGContainer = new Vector.<MovieClip>();
			if (this._isFourScreenInterface)
			{
				_playerBGContainer.push(_fourUI.playerUI1);
				_playerBGContainer.push(_fourUI.playerUI2);
				_playerBGContainer.push(_fourUI.playerUI3);
				_playerBGContainer.push(_fourUI.playerUI4);
				
				for (var i:int=0; i<_playerBGContainer.length; i++)
				{
					_playerBGContainer[i].gotoAndStop(1);
					_playerBGContainer[i].Four_OneUI.playerBG1.gotoAndStop(1);
					_playerBGContainer[i].Four_OneUI.videoName.text="";
					_playerBGContainer[i].Four_OneUI.videoTime.text="";
				}
			}
			else
			{
				_playerBGContainer.push(_nineUI.playerUI1);
				_playerBGContainer.push(_nineUI.playerUI2);
				_playerBGContainer.push(_nineUI.playerUI3);
				_playerBGContainer.push(_nineUI.playerUI4);
				_playerBGContainer.push(_nineUI.playerUI5);
				_playerBGContainer.push(_nineUI.playerUI6);
				_playerBGContainer.push(_nineUI.playerUI7);
				_playerBGContainer.push(_nineUI.playerUI8);
				_playerBGContainer.push(_nineUI.playerUI9);
				
				for (var j:int=0; j<_playerBGContainer.length; j++)
				{
					_playerBGContainer[j].gotoAndStop(1);
					_playerBGContainer[i].Nine_OneUI.playerBG1.gotoAndStop(1);
					_playerBGContainer[j].Nine_OneUI.videoName.text="";
					_playerBGContainer[i].Nine_OneUI.videoTime.text="";
				}
			}
			
			for (var k:int=0; k<_playerBGContainer.length; k++)
			{
				_playerBGContainer[k].mouseEnabled = false;
				_playerBGContainer[k].mouseChildren = false;
			}	
		}
		
		private function getCurPageMinLiveContainerIndex():int
		{
			var _len:int = 0;
			if (_isFourScreenInterface)
				_curPageMinLiveContainerIndex = (_curPageNumOfFour - 1) * 4;
			else
				_curPageMinLiveContainerIndex = (_curPageNumOfNine - 1) * 9;
			return _curPageMinLiveContainerIndex;
		}
		
		private function getCurPageMaxLiveContainerIndex():int
		{
			var _len:int = 0;
			if (_isFourScreenInterface)
			{
				if (_curPageNumOfFour <= 1){
					_roomCount <= 4 ? _len = _roomCount : _len = 4;
					_curPageMaxLiveContainerIndex = _len;
				}else{
					if (_curPageNumOfFour < _totalPageNumOfFour)
						_curPageMaxLiveContainerIndex = _curPageNumOfFour * 4;
					else
						_curPageMaxLiveContainerIndex = _roomCount;
				}
			}else{
				if (_curPageNumOfNine <= 1){
					_roomCount <= 9 ? _len = _roomCount : _len = 9;
					_curPageMaxLiveContainerIndex = _len;
				}else{
					if (_curPageNumOfNine < _totalPageNumOfNine)
						_curPageMaxLiveContainerIndex = _curPageNumOfNine * 9;
					else
						_curPageMaxLiveContainerIndex = _roomCount;
				}
			}
			return (_curPageMaxLiveContainerIndex - 1);
		}
		
		//get current page maximum index
		private function getCurPageMaxIndex():void
		{
			var _len:int = 0;
			this._roomCount <= 4 ? _len = _roomCount : _len = 4;
			for (var i:int=0; i<_len; i++)
			{
				this._curPageMaxIndex += (this._liveData[i] as LiveDataVO).liveVO.length;
			}
			this._curPageMaxIndex = this._curPageMaxIndex - 1;
		}
		
		/**
		 *
		 * 页码初始化，计算4/9分屏总页数 
		 * 
		 */		
		private function figureOutTotalPageNum():void
		{
			_roomCount % 4 == 0 ? _totalPageNumOfFour = _roomCount / 4 : _totalPageNumOfFour = _roomCount / 4 + 1;
			_roomCount % 9 == 0 ? _totalPageNumOfNine = _roomCount / 9 : _totalPageNumOfNine = _roomCount / 9 + 1;
			_bottomBar.pageNumberTxt.text = String(this._curPageNumOfFour + "/" + _totalPageNumOfFour);
			trace ("4分屏共有：" + _totalPageNumOfFour + "页");
			trace ("9分屏共有：" + _totalPageNumOfNine + "页");
		} 
		
		private function onLoadTimer(event:TimerEvent):void
		{
			if (!this._loadTimerLock)
			{
				this._loadTimerLock = true;
				createLoadInterface();
			}
		}
				
		
		/**
		 *
		 * 创建视频播放器 
		 * 
		 */
		private function createLoadInterface():void
		{
			if (_curPageStartIndex > _curPageEndIndex)  
			{
				//停止循环添加视频timer
				this._loadTimer.stop(); 
				this._loadTimer.removeEventListener(TimerEvent.TIMER, onLoadTimer);
				this._loadTimerLock = false;
				
				//播放所有暂停的视频
				//for (var i:int=_curPageMinIndex; i <= _curPageMaxIndex; i++)
				//{
					//_nsContainer[i].resume();
				//}
				
				//视频流建立后设置播放器背景可操作
				for (var k:int=0;k<_videoContainer.length; k++)
				{
					_playerBGContainer[k].mouseEnabled = true;
					_playerBGContainer[k].mouseChildren = true;
				}
				
				//控制无信号视频背景提示切换
				if (this._isFourScreenInterface)
				{
					for (var index:int=_videoContainer.length; index<_playerBGContainer.length; index++)
					{
						_playerBGContainer[index].mouseEnabled = false;
						_playerBGContainer[index].mouseChildren = false;
						_playerBGContainer[index].gotoAndStop(1);
						_playerBGContainer[index].Four_OneUI.videoName.text = "";
						_playerBGContainer[index].Four_OneUI.videoTime.text = "";
						_playerBGContainer[index].Four_OneUI.playerBG1.gotoAndStop(2);
					}
				}
				else
				{
					for (var index2:int=_videoContainer.length; index2<_playerBGContainer.length; index2++)
					{
						_playerBGContainer[index2].mouseEnabled = false;
						_playerBGContainer[index2].mouseChildren = false;
						_playerBGContainer[index2].gotoAndStop(1);
						_playerBGContainer[index2].Nine_OneUI.videoName.text = "";
						_playerBGContainer[index2].Nine_OneUI.videoTime.text = "";
						_playerBGContainer[index2].Nine_OneUI.playerBG1.gotoAndStop(2);
					}	
				}
				
				//更新当前时间timer启动
				_updateVideoTimeTimer.reset();
				_updateVideoTimeTimer.start();
				_updateVideoTimeTimer.addEventListener(TimerEvent.TIMER, onUpdateVideoTimeTimer);
				
				//添加轮播控制
				if (_bottomBar.playMethod.currentFrame == 1)
				{
					_loopTimer.reset();
					_loopTimer.start();
					_loopTimer.addEventListener(TimerEvent.TIMER, loopTimerTickHandler);
				}
				
				return;
			}
			
			if (_curContainerIndex == this._videoContainer.length)
			{
				this._videoContainer[_curContainerIndex] = new Sprite();
				this._videoContainer[_curContainerIndex].name = "videoContainer" + _curContainerIndex;
				this._videoContainer[_curContainerIndex].buttonMode = true;
			}
			
			if (this._isFourScreenInterface)
			{
				createVideoBoxForFourScreenInterface();
			}
			else
			{
				createVideoBoxForNineScreenInterface();
			}

			this._videoContainer[_curContainerIndex].addChild(this._videoBoxContainer[_curPageStartIndex]);
			if (!this.contains(this._videoContainer[_curContainerIndex]))
			{
				this.addChild(this._videoContainer[_curContainerIndex]);
			}
			
			connect();
		}
		
		//create four screens interface
		private function createVideoBoxForFourScreenInterface():void
		{
			if (_curContainerVideoCount == 1)
			{
				this._videoBox[_curPageStartIndex] = new Video();
				this._playerBGContainer[_curContainerIndex].gotoAndStop(1);
				this._playerBGContainer[_curContainerIndex].Four_OneUI.playerBG1.gotoAndStop(1);
				this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Four_OneUI.playerBG1.width;
				this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Four_OneUI.playerBG1.height;
				this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Four_OneUI.playerBG1.x;
				this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Four_OneUI.playerBG1.y;
				this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				this._playerBGContainer[_curContainerIndex].Four_OneUI.videoName.text = this._liveData[_curPageLiveContainerIndex].liveName;
			}
			else if (_curContainerVideoCount == 2)
			{
				if (this._curContainerVideoIndex == 0)
				{
					this._videoBox[_curPageStartIndex] = new Video();
					
					this._playerBGContainer[_curContainerIndex].gotoAndStop(2);
					this._playerBGContainer[_curContainerIndex].Four_TwoUI.playerBG1.gotoAndStop(1);
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Four_TwoUI.playerBG1.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Four_TwoUI.playerBG1.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Four_TwoUI.playerBG1.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Four_TwoUI.playerBG1.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
				else
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(2);
					this._playerBGContainer[_curContainerIndex].Four_TwoUI.playerBG2.gotoAndStop(1);
					this._playerBGContainer[_curContainerIndex].Four_TwoUI.videoName.text = this._liveData[_curPageLiveContainerIndex].liveName;
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Four_TwoUI.playerBG2.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Four_TwoUI.playerBG2.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Four_TwoUI.playerBG2.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Four_TwoUI.playerBG2.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
			}
			else if (_curContainerVideoCount == 3)
			{
				if (this._curContainerVideoIndex == 0)
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(3);
					this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG1.gotoAndStop(1);
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG1.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG1.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG1.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG1.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
				else if (this._curContainerVideoIndex == 1)
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(3);
					this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG2.gotoAndStop(1);
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG2.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG2.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG2.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG2.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
				else
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(3);
					this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG3.gotoAndStop(1);
					this._playerBGContainer[_curContainerIndex].Four_ThreeUI.videoName.text = this._liveData[_curPageLiveContainerIndex].liveName;
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG3.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG3.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG3.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Four_ThreeUI.playerBG3.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
			}
			else
			{
				if (this._curContainerVideoIndex == 0)
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(4);
					this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG1.gotoAndStop(1);
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG1.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG1.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG1.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG1.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
				else if (this._curContainerVideoIndex == 1)
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(4);
					this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG2.gotoAndStop(1);
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG2.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG2.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG2.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG2.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
				else if (this._curContainerVideoIndex == 2)
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(4);
					this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG3.gotoAndStop(1);
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG3.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG3.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG3.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG3.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
				else
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(4);
					this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG4.gotoAndStop(1);
					this._playerBGContainer[_curContainerIndex].Four_FourUI.videoName.text = this._liveData[_curPageLiveContainerIndex].liveName;
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG4.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG4.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG4.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Four_FourUI.playerBG4.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
			}
			
			this._videoBoxContainer[_curPageStartIndex] = new Sprite();
			this._videoBoxContainer[_curPageStartIndex].addChild(this._videoBox[_curPageStartIndex]);
		}
		
		//create nine screens interface
		private function createVideoBoxForNineScreenInterface():void
		{
			if (_curContainerVideoCount == 1)
			{
				this._videoBox[_curPageStartIndex] = new Video();
				this._playerBGContainer[_curContainerIndex].gotoAndStop(1);
				this._playerBGContainer[_curContainerIndex].Nine_OneUI.playerBG1.gotoAndStop(1);
				this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Nine_OneUI.playerBG1.width;
				this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Nine_OneUI.playerBG1.height;
				this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Nine_OneUI.playerBG1.x;
				this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Nine_OneUI.playerBG1.y;
				this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				this._playerBGContainer[_curContainerIndex].Nine_OneUI.videoName.text = this._liveData[_curPageLiveContainerIndex].liveName;
			}
			else if (_curContainerVideoCount == 2)
			{
				if (this._curContainerVideoIndex == 0)
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(2);
					this._playerBGContainer[_curContainerIndex].Nine_TwoUI.playerBG1.gotoAndStop(1);
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Nine_TwoUI.playerBG1.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Nine_TwoUI.playerBG1.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Nine_TwoUI.playerBG1.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Nine_TwoUI.playerBG1.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
				else
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(2);
					this._playerBGContainer[_curContainerIndex].Nine_TwoUI.playerBG2.gotoAndStop(1);
					this._playerBGContainer[_curContainerIndex].Nine_TwoUI.videoName.text = this._liveData[_curPageLiveContainerIndex].liveName;
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Nine_TwoUI.playerBG2.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Nine_TwoUI.playerBG2.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Nine_TwoUI.playerBG2.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Nine_TwoUI.playerBG2.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
			}
			else if (_curContainerVideoCount == 3)
			{
				if (this._curContainerVideoIndex == 0)
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(3);
					this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG1.gotoAndStop(1);
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG1.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG1.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG1.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG1.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
				else if (this._curContainerVideoIndex == 1)
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(3);
					this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG2.gotoAndStop(1);
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG2.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG2.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG2.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG2.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
				else
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(3);
					this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG3.gotoAndStop(1);
					this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.videoName.text = this._liveData[_curPageLiveContainerIndex].liveName;
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG3.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG3.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG3.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Nine_ThreeUI.playerBG3.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
			}
			else
			{
				if (this._curContainerVideoIndex == 0)
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(4);
					this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG1.gotoAndStop(1);
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG1.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG1.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG1.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG1.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
				else if (this._curContainerVideoIndex == 1)
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(4);
					this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG2.gotoAndStop(1);
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG2.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG2.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG2.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG2.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
				else if (this._curContainerVideoIndex == 2)
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(4);
					this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG3.gotoAndStop(1);
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG3.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG3.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG3.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG3.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
				else
				{
					this._videoBox[_curPageStartIndex] = new Video();
					this._playerBGContainer[_curContainerIndex].gotoAndStop(4);
					this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG4.gotoAndStop(1);
					this._playerBGContainer[_curContainerIndex].Nine_FourUI.videoName.text = this._liveData[_curPageLiveContainerIndex].liveName;
					this._videoBox[_curPageStartIndex].width = this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG4.width;
					this._videoBox[_curPageStartIndex].height = this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG4.height;
					this._videoBox[_curPageStartIndex].x = this._playerBGContainer[_curContainerIndex].x + this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG4.x;
					this._videoBox[_curPageStartIndex].y = this._playerBGContainer[_curContainerIndex].y + this._playerBGContainer[_curContainerIndex].Nine_FourUI.playerBG4.y;
					this._videoBox[_curPageStartIndex].name = "videoBox" + _curPageStartIndex;
				}
			} 
			
			this._videoBoxContainer[_curPageStartIndex] = new Sprite();
			this._videoBoxContainer[_curPageStartIndex].addChild(this._videoBox[_curPageStartIndex]);
		}
		
		// add play control event listener
		private function addListener():void
		{
			this._bottomBar.changeScreenBtn.fourBtn.addEventListener(MouseEvent.CLICK, onFourBtnClick);
			this._bottomBar.changeScreenBtn.nineBtn.addEventListener(MouseEvent.CLICK, onNineBtnClick);	
			this._bottomBar.playMethod.addEventListener(MouseEvent.CLICK, onPlayMethodClick);
			this._bottomBar.gobackBtn.addEventListener(MouseEvent.CLICK, onGoBackBtnClick);
			this._bottomBar.gofrontBtn.addEventListener(MouseEvent.CLICK, onGoFrontBtnClick);
			this._bottomBar.fullscreenBtn.addEventListener(MouseEvent.CLICK, onFullScreenBtnClick);
			this._bottomBar.quitFullscreenBtn.addEventListener(MouseEvent.CLICK, onQuitFullScreenBtnClick);
			this._bottomBar.timeSettingMC.addEventListener(FocusEvent.FOCUS_IN, onTimeSettingFocusIn);
			this._bottomBar.timeSettingMC.addEventListener(FocusEvent.FOCUS_OUT, onTimeSettingFocusOut);
			this._bottomBar.playMethod.addEventListener(MouseEvent.MOUSE_OVER, onPlayMethodMouseOver);
			this._bottomBar.playMethod.addEventListener(MouseEvent.MOUSE_OUT, onPlayMethodMouseOut);			
			this.addEventListener(Event.REMOVED_FROM_STAGE, destroy);
			addFourUIEventListener();
		}
		
		//添加四分屏模式下事件监听
		private function addFourUIEventListener():void
		{
			_fourUI.playerUI1.buttonMode = true;
			_fourUI.playerUI2.buttonMode = true;
			_fourUI.playerUI3.buttonMode = true;
			_fourUI.playerUI4.buttonMode = true;
			
			_fourUI.playerUI1.addEventListener(MouseEvent.CLICK, onFourClick);
			_fourUI.playerUI2.addEventListener(MouseEvent.CLICK, onFourClick);
			_fourUI.playerUI3.addEventListener(MouseEvent.CLICK, onFourClick);
			_fourUI.playerUI4.addEventListener(MouseEvent.CLICK, onFourClick);
			_fourUI.playerUI1.addEventListener(MouseEvent.MOUSE_OVER, onFourPlayerUIMouseOver);
			_fourUI.playerUI1.addEventListener(MouseEvent.MOUSE_OUT, onFourPlayerUIMouseOut);
			_fourUI.playerUI2.addEventListener(MouseEvent.MOUSE_OVER, onFourPlayerUIMouseOver);
			_fourUI.playerUI2.addEventListener(MouseEvent.MOUSE_OUT, onFourPlayerUIMouseOut);
			_fourUI.playerUI3.addEventListener(MouseEvent.MOUSE_OVER, onFourPlayerUIMouseOver);
			_fourUI.playerUI3.addEventListener(MouseEvent.MOUSE_OUT, onFourPlayerUIMouseOut);
			_fourUI.playerUI4.addEventListener(MouseEvent.MOUSE_OVER, onFourPlayerUIMouseOver);
			_fourUI.playerUI4.addEventListener(MouseEvent.MOUSE_OUT, onFourPlayerUIMouseOut);
			
		}
		
		private function onFourPlayerUIMouseOver(e:MouseEvent):void
		{
			var name:String = e.currentTarget.name;
			switch (name)
			{
				case "playerUI1":
					showFourBorder(_fourUI.playerUI1);
					break;
				case "playerUI2":
					showFourBorder(_fourUI.playerUI2);
					break;
				case "playerUI3":
					showFourBorder(_fourUI.playerUI3);
					break;
				case "playerUI4":
					showFourBorder(_fourUI.playerUI4);
					break;
				default:
					break;
			}
		}
		
		private function onFourPlayerUIMouseOut(e:MouseEvent):void
		{
			var name:String = e.currentTarget.name;
			switch (name)
			{
				case "playerUI1":
					hideFourBorder(_fourUI.playerUI1);
					break;
				case "playerUI2":
					hideFourBorder(_fourUI.playerUI2);
					break;
				case "playerUI3":
					hideFourBorder(_fourUI.playerUI3);
					break;
				case "playerUI4":
					hideFourBorder(_fourUI.playerUI4);
					break;
				default:
					break;
			}
		}
		
		private function showFourBorder(o:MovieClip):void
		{
			if (o.currentFrame == 1){
				o.Four_OneUI.borderUI.visible = true;
			}else if (o.currentFrame == 2){
				o.Four_TwoUI.borderUI.visible = true;
			}else if (o.currentFrame == 3){
				o.Four_ThreeUI.borderUI.visible = true;
			}else{
				o.Four_FourUI.borderUI.visible = true;
			}
		}
		
		private function hideFourBorder(o:MovieClip):void
		{
			if (o.currentFrame == 1){
				o.Four_OneUI.borderUI.visible = false;
			}else if (o.currentFrame == 2){
				o.Four_TwoUI.borderUI.visible = false;
			}else if (o.currentFrame == 3){
				o.Four_ThreeUI.borderUI.visible = false;
			}else{
				o.Four_FourUI.borderUI.visible = false;
			}
		}
		
		private function addNineUIEventListener():void
		{
			_nineUI.playerUI1.buttonMode = true;
			_nineUI.playerUI2.buttonMode = true;
			_nineUI.playerUI3.buttonMode = true;
			_nineUI.playerUI4.buttonMode = true;
			_nineUI.playerUI5.buttonMode = true;
			_nineUI.playerUI6.buttonMode = true;
			_nineUI.playerUI7.buttonMode = true;
			_nineUI.playerUI8.buttonMode = true;
			_nineUI.playerUI9.buttonMode = true;
			
			_nineUI.playerUI1.addEventListener(MouseEvent.CLICK, onNineClick);
			_nineUI.playerUI2.addEventListener(MouseEvent.CLICK, onNineClick);
			_nineUI.playerUI3.addEventListener(MouseEvent.CLICK, onNineClick);
			_nineUI.playerUI4.addEventListener(MouseEvent.CLICK, onNineClick);
			_nineUI.playerUI5.addEventListener(MouseEvent.CLICK, onNineClick);
			_nineUI.playerUI6.addEventListener(MouseEvent.CLICK, onNineClick);
			_nineUI.playerUI7.addEventListener(MouseEvent.CLICK, onNineClick);
			_nineUI.playerUI8.addEventListener(MouseEvent.CLICK, onNineClick);
			_nineUI.playerUI9.addEventListener(MouseEvent.CLICK, onNineClick);
			
			_nineUI.playerUI1.addEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
			_nineUI.playerUI1.addEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
			_nineUI.playerUI2.addEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
			_nineUI.playerUI2.addEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
			_nineUI.playerUI3.addEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
			_nineUI.playerUI3.addEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
			_nineUI.playerUI4.addEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
			_nineUI.playerUI4.addEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
			_nineUI.playerUI5.addEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
			_nineUI.playerUI5.addEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
			_nineUI.playerUI6.addEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
			_nineUI.playerUI6.addEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
			_nineUI.playerUI7.addEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
			_nineUI.playerUI7.addEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
			_nineUI.playerUI8.addEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
			_nineUI.playerUI8.addEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
			_nineUI.playerUI9.addEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
			_nineUI.playerUI9.addEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
		}
		
		private function onNinePlayerMouseOver(e:MouseEvent):void
		{
			var name:String = e.currentTarget.name;
			switch (name)
			{
				case "playerUI1":
					showNineBorder(_nineUI.playerUI1);
					break;
				case "playerUI2":
					showNineBorder(_nineUI.playerUI2);
					break;
				case "playerUI3":
					showNineBorder(_nineUI.playerUI3);
					break;
				case "playerUI4":
					showNineBorder(_nineUI.playerUI4);
					break;
				case "playerUI5":
					showNineBorder(_nineUI.playerUI5);
					break;
				case "playerUI6":
					showNineBorder(_nineUI.playerUI6);
					break;
				case "playerUI7":
					showNineBorder(_nineUI.playerUI7);
					break;
				case "playerUI8":
					showNineBorder(_nineUI.playerUI8);
					break;
				case "playerUI9":
					showNineBorder(_nineUI.playerUI9);
					break;
				default:
					break;
			}
		}
		
		private function onNinePlayerMouseOut(e:MouseEvent):void
		{
			var name:String = e.currentTarget.name;
			switch (name)
			{
				case "playerUI1":
					hideNineBorder(_nineUI.playerUI1);
					break;
				case "playerUI2":
					hideNineBorder(_nineUI.playerUI2);
					break;
				case "playerUI3":
					hideNineBorder(_nineUI.playerUI3);
					break;
				case "playerUI4":
					hideNineBorder(_nineUI.playerUI4);
					break;
				case "playerUI5":
					hideNineBorder(_nineUI.playerUI5);
					break;
				case "playerUI6":
					hideNineBorder(_nineUI.playerUI6);
					break;
				case "playerUI7":
					hideNineBorder(_nineUI.playerUI7);
					break;
				case "playerUI8":
					hideNineBorder(_nineUI.playerUI8);
					break;
				case "playerUI9":
					hideNineBorder(_nineUI.playerUI9);
					break;
				default:
					break;
			}
		}
		
		private function showNineBorder(o:MovieClip):void
		{
			if (o.currentFrame == 1){
				o.Nine_OneUI.borderUI.visible = true;
			}else if (o.currentFrame == 2){
				o.Nine_TwoUI.borderUI.visible = true;
			}else if (o.currentFrame == 3){
				o.Nine_ThreeUI.borderUI.visible = true;
			}else{
				o.Nine_FourUI.borderUI.visible = true;
			}
		}
		
		private function hideNineBorder(o:MovieClip):void
		{
			if (o.currentFrame == 1){
				o.Nine_OneUI.borderUI.visible = false;
			}else if (o.currentFrame == 2){
				o.Nine_TwoUI.borderUI.visible = false;
			}else if (o.currentFrame == 3){
				o.Nine_ThreeUI.borderUI.visible = false;
			}else{
				o.Nine_FourUI.borderUI.visible = false;
			}
		}
		
		private function onFourBtnClick(event:MouseEvent):void
		{
			createFourScreenInterface();
		}
		
		/**
		 *
		 * create four screen interface 
		 * 
		 */		
		private function createFourScreenInterface():void
		{
			if (this._isFourScreenInterface)
			{
				return;
			}
			
			clear();
			
			if (_fourUI==null)
			{
				_fourUI = new FourUI();
				_fourUI.x = 0;
				_fourUI.y = 0;
				this.addChild(_fourUI);
			}
			this.addFourUIEventListener();
			this._isFourScreenInterface = true;
			this._loadTimerLock = false;	
			this._curPageNumOfFour = getPageNumByCurPageMinLiveContainerIndex();
			this._curPageMinIndex = getCurPageMinIndexByCurPageNum();
			this._curPageMaxIndex = getCurPageMaxIndexByCurPageNum();
			this._curPageStartIndex = this._curPageMinIndex;
			this._curPageEndIndex = this._curPageMaxIndex;
			
			this._curContainerIndex = 0;
			this._curContainerVideoIndex = 0;
			this._videoContainer = new Vector.<Sprite>();
			this._curPageMinLiveContainerIndex = getCurPageMinLiveContainerIndex();
			this._curPageLiveContainerIndex = this._curPageMinLiveContainerIndex;
			this._curContainerVideoCount = this._liveData[_curPageLiveContainerIndex].liveVO.length;
			this.pageNumberText = String(this._curPageNumOfFour + "/" + this._totalPageNumOfFour);
			
			this.initPlayerBGContainer();
			
			this._loadTimer.reset();
			this._loadTimer.start();
			this._loadTimer.addEventListener(TimerEvent.TIMER, onLoadTimer);	
		}
		
		/**
		 * 
		 * @param name ：播放器背景控件名称
		 * get video source of the current video container
		 * 
		 */		
		private function getCurVideoArrayForFourScreen(name:String):void
		{
			this._curVideoContainer = new Sprite();
			switch (name)
			{
				case "playerUI1":
					this._curVideoContainer = this._videoContainer[0]; 
					break;
				case "playerUI2":
					this._curVideoContainer = this._videoContainer[1]; 
					break;
				case "playerUI3":
					this._curVideoContainer = this._videoContainer[2]; 
					break;
				case "playerUI4":
					this._curVideoContainer = this._videoContainer[3]; 
					break;
				default:
					break;
			}
		}
		
		// four screen click event handler
		private function onFourClick(e:MouseEvent):void
		{
			var name:String = e.currentTarget.name;
			getCurVideoArrayForFourScreen(name);
			_curVideoBox = new Sprite();
		
			if (e.currentTarget.width < 1000)
			{
				if (e.currentTarget.currentFrame == 1)
				{
					var title1:String = e.currentTarget.Four_OneUI.videoName.text;
					_curPlayerX = e.currentTarget.x;
					_curPlayerY = e.currentTarget.y;
					e.currentTarget.Four_OneUI.gotoAndStop(2);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Four_OneUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0)..height = e.currentTarget.Four_OneUI.playerBG1.height;
					
					e.currentTarget.Four_OneUI.videoName.text = title1;
					
					e.currentTarget.x = 0;
					e.currentTarget.y = 0;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Four_OneUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Four_OneUI.playerBG1.y;
					
					this._fourUI.setChildIndex(e.currentTarget as MovieClip, this._fourUI.numChildren - 1);
					this.setChildIndex(_fourUI, numChildren - 1);
					this.setChildIndex(this._curVideoContainer, numChildren - 1);
						
				}
				else if (e.currentTarget.currentFrame == 2)
				{
					var title2:String = e.currentTarget.Four_TwoUI.videoName.text;
					_curPlayerX = e.currentTarget.x;
					_curPlayerY = e.currentTarget.y;
					e.currentTarget.Four_TwoUI.gotoAndStop(2);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Four_TwoUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Four_TwoUI.playerBG1.height;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).width = e.currentTarget.Four_TwoUI.playerBG2.width;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).height = e.currentTarget.Four_TwoUI.playerBG2.height;
					
					e.currentTarget.Four_TwoUI.videoName.text = title2;
					
					e.currentTarget.x = 0;
					e.currentTarget.y = 0;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.Four_TwoUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.Four_TwoUI.playerBG1.y;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).x = e.currentTarget.Four_TwoUI.playerBG2.x;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).y = e.currentTarget.Four_TwoUI.playerBG2.y;
					
					
					
					this._fourUI.setChildIndex(e.currentTarget as MovieClip, this._fourUI.numChildren - 1);
					this.setChildIndex(_fourUI, numChildren - 1);
					this.setChildIndex(this._curVideoContainer, numChildren - 1);
					
					this._curVideoBox = this._curVideoContainer.getChildAt(1) as Sprite;
					this._curVideoContainer.getChildAt(0).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(1).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
				}
				else if (e.currentTarget.currentFrame == 3)
				{
					var title3:String = e.currentTarget.Four_ThreeUI.videoName.text;
					_curPlayerX = e.currentTarget.x;
					_curPlayerY = e.currentTarget.y;
					e.currentTarget.Four_ThreeUI.gotoAndStop(2);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Four_ThreeUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Four_ThreeUI.playerBG1.height;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).width = e.currentTarget.Four_ThreeUI.playerBG2.width;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).height = e.currentTarget.Four_ThreeUI.playerBG2.height;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).width = e.currentTarget.Four_ThreeUI.playerBG3.width;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).height = e.currentTarget.Four_ThreeUI.playerBG3.height;
					
					e.currentTarget.Four_ThreeUI.videoName.text = title3;
					
					e.currentTarget.x = 0;
					e.currentTarget.y = 0;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.Four_ThreeUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.Four_ThreeUI.playerBG1.y;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).x = e.currentTarget.Four_ThreeUI.playerBG2.x;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).y = e.currentTarget.Four_ThreeUI.playerBG2.y;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).x = e.currentTarget.Four_ThreeUI.playerBG3.x;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).y = e.currentTarget.Four_ThreeUI.playerBG3.y;
					
					this._fourUI.setChildIndex(e.currentTarget as MovieClip, this._fourUI.numChildren - 1);
					this.setChildIndex(_fourUI, numChildren - 1);
					this.setChildIndex(this._curVideoContainer, numChildren - 1);
					
					this._curVideoBox = this._curVideoContainer.getChildAt(2) as Sprite;
					this._curVideoContainer.getChildAt(0).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(1).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(2).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
				}
				else 
				{
					var title4:String = e.currentTarget.Four_FourUI.videoName.text;
					_curPlayerX = e.currentTarget.x;
					_curPlayerY = e.currentTarget.y;
					e.currentTarget.Four_FourUI.gotoAndStop(2);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Four_FourUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Four_FourUI.playerBG1.height;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).width = e.currentTarget.Four_FourUI.playerBG2.width;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).height = e.currentTarget.Four_FourUI.playerBG2.height;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).width = e.currentTarget.Four_FourUI.playerBG3.width;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).height = e.currentTarget.Four_FourUI.playerBG3.height;
					
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).width = e.currentTarget.Four_FourUI.playerBG4.width;
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).height = e.currentTarget.Four_FourUI.playerBG4.height;
					
					e.currentTarget.Four_FourUI.videoName.text = title4;
					
					e.currentTarget.x = 0;
					e.currentTarget.y = 0;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.Four_FourUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.Four_FourUI.playerBG1.y;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).x = e.currentTarget.Four_FourUI.playerBG2.x;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).y = e.currentTarget.Four_FourUI.playerBG2.y;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).x = e.currentTarget.Four_FourUI.playerBG3.x;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).y = e.currentTarget.Four_FourUI.playerBG3.y;
					
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).x = e.currentTarget.Four_FourUI.playerBG4.x;
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).y = e.currentTarget.Four_FourUI.playerBG4.y;
					
					this._fourUI.setChildIndex(e.currentTarget as MovieClip, this._fourUI.numChildren - 1);
					this.setChildIndex(_fourUI, numChildren - 1);
					this.setChildIndex(this._curVideoContainer, numChildren - 1);
					
					this._curVideoBox = this._curVideoContainer.getChildAt(3) as Sprite;
					this._curVideoContainer.getChildAt(0).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(1).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(2).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(3).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
				}
				
				if (_loopTimer.running)
				{
					this._hasLoopTimer = true;
					this._loopTimer.stop();
					this._loopTimer.removeEventListener(TimerEvent.TIMER, loopTimerTickHandler);
				}
			}
			else
			{
				if (e.currentTarget.currentFrame == 1)
				{
					var title5:String = e.currentTarget.Four_OneUI.videoName.text;
					e.currentTarget.Four_OneUI.gotoAndStop(1);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Four_OneUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Four_OneUI.playerBG1.height;
					
					e.currentTarget.Four_OneUI.videoName.text = title5;
					
					e.currentTarget.x = _curPlayerX;
					e.currentTarget.y = _curPlayerY;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Four_OneUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Four_OneUI.playerBG1.y;
					
					_curPlayerX = 0;
					_curPlayerY = 0;
					
					this.setChildIndex(this._curVideoContainer, 0);
					this._fourUI.setChildIndex(e.currentTarget as MovieClip, 0);
					this.setChildIndex(_fourUI, 0);
				}
				else if (e.currentTarget.currentFrame == 2)
				{
					var title6:String = e.currentTarget.Four_TwoUI.videoName.text;
					e.currentTarget.Four_TwoUI.gotoAndStop(1);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Four_TwoUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Four_TwoUI.playerBG1.height;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).width = e.currentTarget.Four_TwoUI.playerBG2.width;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).height = e.currentTarget.Four_TwoUI.playerBG2.height;
					
					e.currentTarget.Four_TwoUI.videoName.text = title6;
					
					e.currentTarget.x = _curPlayerX;
					e.currentTarget.y = _curPlayerY;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Four_TwoUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Four_TwoUI.playerBG1.y;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Four_TwoUI.playerBG2.x;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Four_TwoUI.playerBG2.y;
					
					_curPlayerX = 0;
					_curPlayerY = 0;
					
					this.setChildIndex(this._curVideoContainer, 0);
					this._fourUI.setChildIndex(e.currentTarget as MovieClip, 0);
					this.setChildIndex(_fourUI, 0);
					
					this._curVideoBox = new Sprite();
					this._curVideoContainer.getChildAt(0).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(1).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
				}
				else if (e.currentTarget.currentFrame == 3)
				{
					var title7:String = e.currentTarget.Four_ThreeUI.videoName.text;
					e.currentTarget.Four_ThreeUI.gotoAndStop(1);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Four_ThreeUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Four_ThreeUI.playerBG1.height;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).width = e.currentTarget.Four_ThreeUI.playerBG2.width;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).height = e.currentTarget.Four_ThreeUI.playerBG2.height;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).width = e.currentTarget.Four_ThreeUI.playerBG3.width;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).height = e.currentTarget.Four_ThreeUI.playerBG3.height;
					
					e.currentTarget.Four_ThreeUI.videoName.text = title7;
					
					e.currentTarget.x = _curPlayerX;
					e.currentTarget.y = _curPlayerY;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Four_ThreeUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Four_ThreeUI.playerBG1.y;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Four_ThreeUI.playerBG2.x;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Four_ThreeUI.playerBG2.y;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Four_ThreeUI.playerBG3.x;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Four_ThreeUI.playerBG3.y;
					
					_curPlayerX = 0;
					_curPlayerY = 0;
					
					this.setChildIndex(this._curVideoContainer, 0);
					this._fourUI.setChildIndex(e.currentTarget as MovieClip, 0);
					this.setChildIndex(_fourUI, 0);
					
					this._curVideoBox = new Sprite();
					this._curVideoContainer.getChildAt(0).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(1).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(2).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
				}
				else 
				{
					var title8:String = e.currentTarget.Four_FourUI.videoName.text;
					e.currentTarget.Four_FourUI.gotoAndStop(1);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Four_FourUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Four_FourUI.playerBG1.height;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).width = e.currentTarget.Four_FourUI.playerBG2.width;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).height = e.currentTarget.Four_FourUI.playerBG2.height;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).width = e.currentTarget.Four_FourUI.playerBG3.width;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).height = e.currentTarget.Four_FourUI.playerBG3.height;
					
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).width = e.currentTarget.Four_FourUI.playerBG4.width;
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).height = e.currentTarget.Four_FourUI.playerBG4.height;
					
					e.currentTarget.Four_FourUI.videoName.text = title8;
					
					e.currentTarget.x = _curPlayerX;
					e.currentTarget.y = _curPlayerY;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Four_FourUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Four_FourUI.playerBG1.y;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Four_FourUI.playerBG2.x;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Four_FourUI.playerBG2.y;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Four_FourUI.playerBG3.x;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Four_FourUI.playerBG3.y;
					
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Four_FourUI.playerBG4.x;
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Four_FourUI.playerBG4.y;
					
					_curPlayerX = 0;
					_curPlayerY = 0;
					
					this.setChildIndex(this._curVideoContainer, 0);
					this._fourUI.setChildIndex(e.currentTarget as MovieClip, 0);
					this.setChildIndex(_fourUI, 0);
					
					this._curVideoBox = new Sprite();
					this._curVideoContainer.getChildAt(0).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(1).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(2).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(3).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
				}
				
				if (this._hasLoopTimer)
				{
					this._hasLoopTimer = false;
					this._loopTimer.start();
					this._loopTimer.addEventListener(TimerEvent.TIMER, loopTimerTickHandler);
				}
			}
		}
		
		// video box click event handler 
		private function onVideoBoxClick(e:MouseEvent):void
		{
			var tX:Number = e.currentTarget.getChildAt(0).x;
			var tY:Number = e.currentTarget.getChildAt(0).y;
			var tWidth:Number = e.currentTarget.getChildAt(0).width;
			var tHeight:Number = e.currentTarget.getChildAt(0).height;
			
			if (e.currentTarget == _curVideoBox)
			{
				return;
			}
			else
			{
				this._curVideoContainer.setChildIndex(_curVideoBox, _curVideoContainer.numChildren - 1);
				this._curVideoContainer.setChildIndex(e.currentTarget as Sprite, _curVideoContainer.numChildren - 1);
				
				TweenLite.to(_curVideoBox.getChildAt(0), 1, {x: tX, y: tY});
				TweenLite.to(e.currentTarget.getChildAt(0), 1, {x: _curVideoBox.getChildAt(0).x, y: _curVideoBox.getChildAt(0).y});
				
				TweenLite.to(_curVideoBox.getChildAt(0), 1, {width: tWidth, height: tHeight});
				TweenLite.to(e.currentTarget.getChildAt(0), 1, {width: _curVideoBox.getChildAt(0).width, height: _curVideoBox.getChildAt(0).height});
				_curVideoBox = e.currentTarget as Sprite;
				
				if (_lockMouseInterval == 0)
				{
					this.mouseEnabled = false;
					this.mouseChildren = false;
					_lockMouseInterval = setInterval(lockMouse, 1000);
				}
			}
		}
		
		// lock mouse
		private function lockMouse():void
		{
			clearInterval(_lockMouseInterval);
			this.mouseEnabled = true;
			this.mouseChildren = true;
			_lockMouseInterval = 0;
		}
		
		private function onNineBtnClick(event:MouseEvent):void
		{
			createNineScreenInterface();
		}
		
		// create nine screen interface
		private function createNineScreenInterface():void
		{
			if (!this._isFourScreenInterface)
			{
				return;
			}
		
			clear();
			if (_nineUI == null)
			{
				_nineUI = new NineUI();
				_nineUI.x = 0;
				_nineUI.y = 0;
				this.addChild(_nineUI);
			}
			this.addNineUIEventListener();
			this._isFourScreenInterface = false;
			this._loadTimerLock = false;
			
			this._curPageNumOfNine = getPageNumByCurPageMinLiveContainerIndex();
			this._curPageMinIndex = getCurPageMinIndexByCurPageNum();
			this._curPageMaxIndex = getCurPageMaxIndexByCurPageNum();
			this._curPageStartIndex = this._curPageMinIndex;
			this._curPageEndIndex = this._curPageMaxIndex;
			
			this._curContainerIndex = 0;
			this._curContainerVideoIndex = 0;
			this._videoContainer = new Vector.<Sprite>();
			this._curPageMinLiveContainerIndex = getCurPageMinLiveContainerIndex();
			this._curPageLiveContainerIndex = this._curPageMinLiveContainerIndex;
			this._curContainerVideoCount = this._liveData[_curPageLiveContainerIndex].liveVO.length;
			this.pageNumberText = String(this._curPageNumOfNine + "/" + this._totalPageNumOfNine);
			this.initPlayerBGContainer();
			this._loadTimer.reset();
			this._loadTimer.start();
			this._loadTimer.addEventListener(TimerEvent.TIMER, onLoadTimer);
			
		}
		
		// get current container video source
		private function getCurVideoArrayForNineScreen(name:String):void
		{
			this._curVideoContainer = new Sprite();
			switch (name)
			{
				case "playerUI1":
					this._curVideoContainer = this._videoContainer[0]; 
					break;
				case "playerUI2":
					this._curVideoContainer = this._videoContainer[1]; 
					break;
				case "playerUI3":
					this._curVideoContainer = this._videoContainer[2]; 
					break;
				case "playerUI4":
					this._curVideoContainer = this._videoContainer[3]; 
					break;
				case "playerUI5":
					this._curVideoContainer = this._videoContainer[4]; 
					break;
				case "playerUI6":
					this._curVideoContainer = this._videoContainer[5]; 
					break;
				case "playerUI7":
					this._curVideoContainer = this._videoContainer[6]; 
					break;
				case "playerUI8":
					this._curVideoContainer = this._videoContainer[7]; 
					break;
				case "playerUI9":
					this._curVideoContainer = this._videoContainer[8]; 
					break;
				default:
					break;
			}
		}
		
		// nine screen click handler
		private function onNineClick(e:MouseEvent):void
		{
			var name:String = e.currentTarget.name;
			getCurVideoArrayForNineScreen(name);
			_curVideoBox = new Sprite();;
			
			if (e.currentTarget.width < 1000)
			{
				if (e.currentTarget.currentFrame == 1)
				{
					var title1:String = e.currentTarget.Nine_OneUI.videoName.text;
					_curPlayerX = e.currentTarget.x;
					_curPlayerY = e.currentTarget.y;
					e.currentTarget.Nine_OneUI.gotoAndStop(2);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Nine_OneUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0)..height = e.currentTarget.Nine_OneUI.playerBG1.height;
					
					e.currentTarget.Nine_OneUI.videoName.text = title1;
					
					e.currentTarget.x = 0;
					e.currentTarget.y = 0;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.Nine_OneUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.Nine_OneUI.playerBG1.y;
					
					this._nineUI.setChildIndex(e.currentTarget as MovieClip, this._nineUI.numChildren - 1);
					this.setChildIndex(_nineUI, numChildren - 1);
					this.setChildIndex(this._curVideoContainer, numChildren - 1);
					
				}
				else if (e.currentTarget.currentFrame == 2)
				{
					var title2:String = e.currentTarget.Nine_TwoUI.videoName.text;
					_curPlayerX = e.currentTarget.x;
					_curPlayerY = e.currentTarget.y;
					e.currentTarget.Nine_TwoUI.gotoAndStop(2);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Nine_TwoUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Nine_TwoUI.playerBG1.height;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).width = e.currentTarget.Nine_TwoUI.playerBG2.width;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).height = e.currentTarget.Nine_TwoUI.playerBG2.height;
					
					e.currentTarget.Nine_TwoUI.videoName.text = title2;
					
					e.currentTarget.x = 0;
					e.currentTarget.y = 0;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.Nine_TwoUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.Nine_TwoUI.playerBG1.y;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).x = e.currentTarget.Nine_TwoUI.playerBG2.x;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).y = e.currentTarget.Nine_TwoUI.playerBG2.y;
					
					
					
					this._nineUI.setChildIndex(e.currentTarget as MovieClip, this._nineUI.numChildren - 1);
					this.setChildIndex(_nineUI, numChildren - 1);
					this.setChildIndex(this._curVideoContainer, numChildren - 1);
					
					this._curVideoBox = this._curVideoContainer.getChildAt(1) as Sprite;
					this._curVideoContainer.getChildAt(0).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(1).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
				}
				else if (e.currentTarget.currentFrame == 3)
				{
					var title3:String = e.currentTarget.Nine_ThreeUI.videoName.text;
					_curPlayerX = e.currentTarget.x;
					_curPlayerY = e.currentTarget.y;
					e.currentTarget.Nine_ThreeUI.gotoAndStop(2);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Nine_ThreeUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Nine_ThreeUI.playerBG1.height;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).width = e.currentTarget.Nine_ThreeUI.playerBG2.width;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).height = e.currentTarget.Nine_ThreeUI.playerBG2.height;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).width = e.currentTarget.Nine_ThreeUI.playerBG3.width;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).height = e.currentTarget.Nine_ThreeUI.playerBG3.height;
					
					e.currentTarget.Nine_ThreeUI.videoName.text = title3;
					
					e.currentTarget.x = 0;
					e.currentTarget.y = 0;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.Nine_ThreeUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.Nine_ThreeUI.playerBG1.y;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).x = e.currentTarget.Nine_ThreeUI.playerBG2.x;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).y = e.currentTarget.Nine_ThreeUI.playerBG2.y;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).x = e.currentTarget.Nine_ThreeUI.playerBG3.x;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).y = e.currentTarget.Nine_ThreeUI.playerBG3.y;
					
					this._nineUI.setChildIndex(e.currentTarget as MovieClip, this._nineUI.numChildren - 1);
					this.setChildIndex(_nineUI, numChildren - 1);
					this.setChildIndex(this._curVideoContainer, numChildren - 1);
					
					this._curVideoBox = this._curVideoContainer.getChildAt(2) as Sprite;
					this._curVideoContainer.getChildAt(0).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(1).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(2).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
				}
				else 
				{
					var title4:String = e.currentTarget.Nine_FourUI.videoName.text;
					_curPlayerX = e.currentTarget.x;
					_curPlayerY = e.currentTarget.y;
					e.currentTarget.Nine_FourUI.gotoAndStop(2);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Nine_FourUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Nine_FourUI.playerBG1.height;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).width = e.currentTarget.Nine_FourUI.playerBG2.width;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).height = e.currentTarget.Nine_FourUI.playerBG2.height;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).width = e.currentTarget.Nine_FourUI.playerBG3.width;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).height = e.currentTarget.Nine_FourUI.playerBG3.height;
					
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).width = e.currentTarget.Nine_FourUI.playerBG4.width;
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).height = e.currentTarget.Nine_FourUI.playerBG4.height;
					
					e.currentTarget.Nine_FourUI.videoName.text = title4;
					
					e.currentTarget.x = 0;
					e.currentTarget.y = 0;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.Nine_FourUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.Nine_FourUI.playerBG1.y;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).x = e.currentTarget.Nine_FourUI.playerBG2.x;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).y = e.currentTarget.Nine_FourUI.playerBG2.y;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).x = e.currentTarget.Nine_FourUI.playerBG3.x;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).y = e.currentTarget.Nine_FourUI.playerBG3.y;
					
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).x = e.currentTarget.Nine_FourUI.playerBG4.x;
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).y = e.currentTarget.Nine_FourUI.playerBG4.y;
					
					this._nineUI.setChildIndex(e.currentTarget as MovieClip, this._nineUI.numChildren - 1);
					this.setChildIndex(_nineUI, numChildren - 1);
					this.setChildIndex(this._curVideoContainer, numChildren - 1);
					
					this._curVideoBox = this._curVideoContainer.getChildAt(3) as Sprite;
					this._curVideoContainer.getChildAt(0).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(1).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(2).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(3).addEventListener(MouseEvent.CLICK, onVideoBoxClick);
				}
				
				if (_loopTimer.running)
				{
					this._hasLoopTimer = true;
					this._loopTimer.stop();
					this._loopTimer.removeEventListener(TimerEvent.TIMER, loopTimerTickHandler);
				}
			}
			else
			{
				if (e.currentTarget.currentFrame == 1)
				{
					var title5:String = e.currentTarget.Nine_OneUI.videoName.text;
					e.currentTarget.Nine_OneUI.gotoAndStop(1);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Nine_OneUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Nine_OneUI.playerBG1.height;
					
					e.currentTarget.Nine_OneUI.videoName.text = title5;
					
					e.currentTarget.x = _curPlayerX;
					e.currentTarget.y = _curPlayerY;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Nine_OneUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Nine_OneUI.playerBG1.y;
					
					_curPlayerX = 0;
					_curPlayerY = 0;
					
					this.setChildIndex(this._curVideoContainer, 0);
					this._nineUI.setChildIndex(e.currentTarget as MovieClip, 0);
					this.setChildIndex(_nineUI, 0);
				}
				else if (e.currentTarget.currentFrame == 2)
				{
					var title6:String = e.currentTarget.Nine_TwoUI.videoName.text;
					e.currentTarget.Nine_TwoUI.gotoAndStop(1);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Nine_TwoUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Nine_TwoUI.playerBG1.height;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).width = e.currentTarget.Nine_TwoUI.playerBG2.width;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).height = e.currentTarget.Nine_TwoUI.playerBG2.height;
					
					e.currentTarget.Nine_TwoUI.videoName.text = title6;
					
					e.currentTarget.x = _curPlayerX;
					e.currentTarget.y = _curPlayerY;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Nine_TwoUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Nine_TwoUI.playerBG1.y;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Nine_TwoUI.playerBG2.x;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Nine_TwoUI.playerBG2.y;
					
					_curPlayerX = 0;
					_curPlayerY = 0;
					
					this.setChildIndex(this._curVideoContainer, 0);
					this._nineUI.setChildIndex(e.currentTarget as MovieClip, 0);
					this.setChildIndex(_nineUI, 0);
					
					this._curVideoBox = new Sprite();
					this._curVideoContainer.getChildAt(0).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(1).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
				}
				else if (e.currentTarget.currentFrame == 3)
				{
					var title7:String = e.currentTarget.Nine_ThreeUI.videoName.text;
					e.currentTarget.Nine_ThreeUI.gotoAndStop(1);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Nine_ThreeUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Nine_ThreeUI.playerBG1.height;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).width = e.currentTarget.Nine_ThreeUI.playerBG2.width;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).height = e.currentTarget.Nine_ThreeUI.playerBG2.height;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).width = e.currentTarget.Nine_ThreeUI.playerBG3.width;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).height = e.currentTarget.Nine_ThreeUI.playerBG3.height;
					
					e.currentTarget.Nine_ThreeUI.videoName.text = title7;
					
					e.currentTarget.x = _curPlayerX;
					e.currentTarget.y = _curPlayerY;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Nine_ThreeUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Nine_ThreeUI.playerBG1.y;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Nine_ThreeUI.playerBG2.x;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Nine_ThreeUI.playerBG2.y;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Nine_ThreeUI.playerBG3.x;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Nine_ThreeUI.playerBG3.y;
					
					_curPlayerX = 0;
					_curPlayerY = 0;
					
					this.setChildIndex(this._curVideoContainer, 0);
					this._nineUI.setChildIndex(e.currentTarget as MovieClip, 0);
					this.setChildIndex(_nineUI, 0);
					
					this._curVideoBox = new Sprite();
					this._curVideoContainer.getChildAt(0).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(1).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(2).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
				}
				else 
				{
					var title8:String = e.currentTarget.Nine_FourUI.videoName.text;
					e.currentTarget.Nine_FourUI.gotoAndStop(1);
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).width = e.currentTarget.Nine_FourUI.playerBG1.width;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).height = e.currentTarget.Nine_FourUI.playerBG1.height;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).width = e.currentTarget.Nine_FourUI.playerBG2.width;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).height = e.currentTarget.Nine_FourUI.playerBG2.height;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).width = e.currentTarget.Nine_FourUI.playerBG3.width;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).height = e.currentTarget.Nine_FourUI.playerBG3.height;
					
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).width = e.currentTarget.Nine_FourUI.playerBG4.width;
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).height = e.currentTarget.Nine_FourUI.playerBG4.height;
					
					e.currentTarget.Nine_FourUI.videoName.text = title8;
					
					e.currentTarget.x = _curPlayerX;
					e.currentTarget.y = _curPlayerY;
					
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Nine_FourUI.playerBG1.x;
					(this._curVideoContainer.getChildAt(0) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Nine_FourUI.playerBG1.y;
					
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Nine_FourUI.playerBG2.x;
					(this._curVideoContainer.getChildAt(1) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Nine_FourUI.playerBG2.y;
					
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Nine_FourUI.playerBG3.x;
					(this._curVideoContainer.getChildAt(2) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Nine_FourUI.playerBG3.y;
					
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).x = e.currentTarget.x + e.currentTarget.Nine_FourUI.playerBG4.x;
					(this._curVideoContainer.getChildAt(3) as Sprite).getChildAt(0).y = e.currentTarget.y + e.currentTarget.Nine_FourUI.playerBG4.y;
					
					_curPlayerX = 0;
					_curPlayerY = 0;
					
					this.setChildIndex(this._curVideoContainer, 0);
					this._nineUI.setChildIndex(e.currentTarget as MovieClip, 0);
					this.setChildIndex(_nineUI, 0);
					
					this._curVideoBox = new Sprite();
					this._curVideoContainer.getChildAt(0).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(1).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(2).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
					this._curVideoContainer.getChildAt(3).removeEventListener(MouseEvent.CLICK, onVideoBoxClick);
				}
				
				if (this._hasLoopTimer)
				{
					this._hasLoopTimer = false;
					this._loopTimer.start();
					this._loopTimer.addEventListener(TimerEvent.TIMER, loopTimerTickHandler);
				}
			}
		}

		
		/**
		 * 
		 * @param event
		 * 切换轮播方式为手动或自动
		 * 
		 */		
		private function onPlayMethodClick(event:MouseEvent):void
		{
			if (_bottomBar.playMethod.currentFrame == 1)
			{
				_bottomBar.playMethod.play();
				_bottomBar.gobackBtn.visible = true;
				_bottomBar.gofrontBtn.visible = true;
				_bottomBar.timeSettingMC.visible = false;
				this._loopTimer.stop();
				this._loopTimer.removeEventListener(TimerEvent.TIMER, loopTimerTickHandler);
			}
			else
			{
				_bottomBar.playMethod.play();
				_bottomBar.gobackBtn.visible = false;
				_bottomBar.gofrontBtn.visible = false;
				_bottomBar.timeSettingMC.visible = true;
				this._loopTimer.reset();
				this._loopTimer.start();
				this._loopTimer.addEventListener(TimerEvent.TIMER, loopTimerTickHandler);
			}
		}
		
		/**
		 * 
		 * @param event
		 *退回到前一页处理
		 *  
		 */		
		private function onGoBackBtnClick(event:MouseEvent):void
		{
			if (this._isFourScreenInterface)
			{
				if (this._curPageNumOfFour == 1)
				{
					this._bottomBar.backErrorTip.visible = true;
					if (!this._closeTipLock)
					{
						this._closeTipLock = true;
						_closeTipInterval = setInterval(closeTip, 1500);
					}
					return;
				}	
				else
				{
					clear();
					if (_fourUI == null)
					{
						_fourUI = new FourUI();
						_fourUI.x=0;
						_fourUI.y=0;
						this.addChild(_fourUI);
					}
					this.addFourUIEventListener();
					this._isFourScreenInterface = true;
					this._loadTimerLock = false;
					this._curPageNumOfFour--;
					this._curPageMinIndex = getCurPageMinIndexByCurPageNum();
					this._curPageMaxIndex = getCurPageMaxIndexByCurPageNum();
					this._curPageStartIndex = this._curPageMinIndex;
					this._curPageEndIndex = this._curPageMaxIndex;
					this.pageNumberText = String(this._curPageNumOfFour + "/" + this._totalPageNumOfFour);
				}
			}
			else
			{
				if (this._curPageNumOfNine == 1)
				{
					this._bottomBar.backErrorTip.visible = true;
					if (!this._closeTipLock)
					{
						this._closeTipLock = true;
						_closeTipInterval = setInterval(closeTip, 1500);
					}
					return;
				}
				else
				{
					clear();
					if (_nineUI == null)
					{
						_nineUI = new NineUI();
						_nineUI.x=0;
						_nineUI.y=0;
						this.addChild(_nineUI);
					}
					this.addNineUIEventListener();
					this._isFourScreenInterface = false;
					this._loadTimerLock = false;
					this._curPageNumOfNine--;
					this._curPageMinIndex = getCurPageMinIndexByCurPageNum();
					this._curPageMaxIndex = getCurPageMaxIndexByCurPageNum();
					this._curPageStartIndex = this._curPageMinIndex;
					this._curPageEndIndex = this._curPageMaxIndex;
					this.pageNumberText = String(this._curPageNumOfNine + "/" + this._totalPageNumOfNine);
				}
			}
			
			this._curContainerIndex = 0;
			this._curContainerVideoIndex = 0;
			this._videoContainer = new Vector.<Sprite>();
			this._curPageMinLiveContainerIndex = getCurPageMinLiveContainerIndex();
			this._curPageLiveContainerIndex = this._curPageMinLiveContainerIndex;
			this._curContainerVideoCount = this._liveData[_curPageLiveContainerIndex].liveVO.length;
			
			this.initPlayerBGContainer();
			this._loadTimer.reset();
			this._loadTimer.start();
			this._loadTimer.addEventListener(TimerEvent.TIMER, onLoadTimer);
		}
		
		// close time setting tip
		private function closeTip():void
		{
			this._closeTipLock = false;
			this._bottomBar.backErrorTip.visible = false;
			clearInterval(_closeTipInterval);
		}
		
		/**
		 * 
		 * @param event
		 * 跳转处理
		 *  
		 */		
		private function onGoFrontBtnClick(event:MouseEvent):void
		{
			gotoNextPage();
		}
		
		/**
		 *
		 * 跳转到后一页 
		 * 
		 */		
		private function gotoNextPage():void
		{
			clear();
			if (this._isFourScreenInterface)
			{ 
				if (_fourUI == null)
				{
					_fourUI = new FourUI();
					_fourUI.x=0;
					_fourUI.y=0;
					this.addChild(_fourUI);
				}
				this.addFourUIEventListener();
				this._isFourScreenInterface = true;
				this._loadTimerLock = false;
				
				if (this._curPageNumOfFour < this._totalPageNumOfFour)
				{
					this._curPageNumOfFour++;
					this._curPageMinIndex = this._curPageMaxIndex + 1;
					this._curPageMaxIndex = getCurPageMaxIndexByCurPageNum();
					this._curPageStartIndex = this._curPageMinIndex;
					this._curPageEndIndex = this._curPageMaxIndex;
				}	
				else
				{
					this._curPageNumOfFour = 1;
					this._curPageMinIndex = 0;
					this._curPageMaxIndex = getCurPageMaxIndexByCurPageNum();
					this._curPageStartIndex = this._curPageMinIndex;
					this._curPageEndIndex = this._curPageMaxIndex;
				}
				this.pageNumberText = String(this._curPageNumOfFour + "/" + this._totalPageNumOfFour);
			}
			else
			{
				if (_nineUI == null)
				{
					_nineUI = new NineUI();
					_nineUI.x=0;
					_nineUI.y=0;
					this.addChild(_nineUI);
				}
				this.addNineUIEventListener();
				this._isFourScreenInterface = false;
				this._loadTimerLock = false;
				
				if (this._curPageNumOfNine < this._totalPageNumOfNine)
				{
					this._curPageNumOfNine++;
					this._curPageMinIndex = this._curPageMaxIndex + 1;
					this._curPageMaxIndex = getCurPageMaxIndexByCurPageNum();
					this._curPageStartIndex = this._curPageMinIndex;
					this._curPageEndIndex = this._curPageMaxIndex;
				}
				else
				{
					this._curPageNumOfNine = 1;
					this._curPageMinIndex = 0;
					this._curPageMaxIndex = getCurPageMaxIndexByCurPageNum();
					this._curPageStartIndex = this._curPageMinIndex;
					this._curPageEndIndex = this._curPageMaxIndex;
				}
				this.pageNumberText = String(this._curPageNumOfNine + "/" + this._totalPageNumOfNine);
			}
			
			this._curContainerIndex = 0;
			this._curContainerVideoIndex = 0;
			this._videoContainer = new Vector.<Sprite>();
			this._curPageMinLiveContainerIndex = getCurPageMinLiveContainerIndex();
			this._curPageLiveContainerIndex = this._curPageMinLiveContainerIndex;
			this._curContainerVideoCount = this._liveData[_curPageLiveContainerIndex].liveVO.length;
			
			this._playerBGContainer = null;
			this.initPlayerBGContainer();
			this._loadTimer.reset();
			this._loadTimer.start();
			this._loadTimer.addEventListener(TimerEvent.TIMER, onLoadTimer);
		}
		
		// get the minimum index of current page  by the page number
		private function getCurPageMinIndexByCurPageNum():int
		{
			var index:int = 0;
			if (this._isFourScreenInterface)
			{
				if (this._curPageNumOfFour > 1)
				{
					var len:int = (this._curPageNumOfFour - 1) * 4;
					for (var i:int=0; i<len; i++)
					{
						index += this._liveData[i].liveVO.length;
					}
				}
				else
				{
					index = 0;
				}
			}
			else
			{
				if (this._curPageNumOfNine > 1)
				{
					var len2:int = (this._curPageNumOfNine - 1) * 9;
					for (var j:int=0; j<len2; j++)
					{
						index += this._liveData[j].liveVO.length;
					}
				}
				else
				{
					index = 0;
				}
			}
			return index;
		}
		
		// get the maximum index of current page  by the page number
		private function getCurPageMaxIndexByCurPageNum():int
		{
			var index:int = 0;
			if (this._isFourScreenInterface)
			{
				if (this._curPageNumOfFour < this._totalPageNumOfFour)
				{
					var len:int = this._curPageNumOfFour * 4;
					for (var i:int=0; i<len; i++)
					{
						index += this._liveData[i].liveVO.length;
					}
				}
				else
				{
					index = this._liveCount;
				}
			}
			else
			{
				if (this._curPageNumOfNine < this._totalPageNumOfNine)
				{
					var len2:int = this._curPageNumOfNine * 9;
					for (var j:int=0; j<len2; j++)
					{
						index += this._liveData[j].liveVO.length;
					}
				}
				else
				{
					index = this._liveCount;
				}
			}
			
			return (index - 1);
		}
		
		/**
		 * 
		 * @param event
		 * 轮播时间设定
		 * 
		 */		
		private function onTimeSettingFocusIn(event:FocusEvent):void
		{
			if (_hideTimeSettingLock)
			{
				clearInterval(_hideTimeSettingInterval);
				_hideTimeSettingLock = false;
			}
			_bottomBar.timeSettingMC.visible = true;
			_bottomBar.timeSettingMC.intervalTimeInputBox.text = "";
		}
		
		/**
		 * 
		 * @param event
		 * 轮播时间设定
		 * 
		 */		
		private function onTimeSettingFocusOut(event:FocusEvent):void
		{
			if (StringUtil.trim(_bottomBar.timeSettingMC.intervalTimeInputBox.text) == "")
			{
				_bottomBar.timeSettingMC.intervalTimeInputBox.text = String(this._playIntervalTime);
			}
			else
			{
				this._playIntervalTime = int(_bottomBar.timeSettingMC.intervalTimeInputBox.text);
			}
			
			if (!_hideTimeSettingLock)
			{
				_hideTimeSettingLock = true;
				_hideTimeSettingInterval = setInterval(hideTimeSetting, 2000);
			}
			
			if (_loopTimer.delay != Number(_playIntervalTime * 1000))
			{
				this._loopTimer.reset();
				this._loopTimer.delay = _playIntervalTime * 1000;
				_loopTimer.start();
				_loopTimer.addEventListener(TimerEvent.TIMER, loopTimerTickHandler);
				_bottomBar.timeTipMC.timeContentTxt.text = String(_playIntervalTime);
				_bottomBar.timeTipMC.timeContentTxt.width =  _bottomBar.timeTipMC.timeContentTxt.textWidth + 6;
				_bottomBar.timeTipMC.timeContentTxt.x = _bottomBar.timeTipMC.timeTipTxt.x + _bottomBar.timeTipMC.timeTipTxt.width;
				_bottomBar.timeTipMC.timeUnitTxt.x = _bottomBar.timeTipMC.timeContentTxt.x + _bottomBar.timeTipMC.timeContentTxt.width;
				_bottomBar.timeTipMC.visible = true;
				
			}
			
		}
		
		//hide time setting control
		private function hideTimeSetting():void
		{
			_bottomBar.timeSettingMC.visible = false;  
			_bottomBar.timeTipMC.visible = false;
			clearInterval(_hideTimeSettingInterval);
			_hideTimeSettingInterval = 0;
			_hideTimeSettingLock = false;
		}
		
		// play method button event handler
		private function onPlayMethodMouseOver(event:MouseEvent):void
		{
			if (_bottomBar.playMethod.currentFrame == 1)
			{
				if (_hideTimeSettingInterval)
				{
					clearInterval(_hideTimeSettingInterval);
					_hideTimeSettingInterval = 0;
					_hideTimeSettingLock = false
				}
				_bottomBar.timeSettingMC.visible = true;
			}
		}
		
		// play method button event handler
		private function onPlayMethodMouseOut(event:MouseEvent):void
		{
			if (_hideTimeSettingInterval)
			{
				clearInterval(_hideTimeSettingInterval);
				_hideTimeSettingInterval = 0;
				_hideTimeSettingLock = false;
			}
			
			if (!_hideTimeSettingLock)
			{
				_hideTimeSettingInterval = setInterval(hideTimeSetting, 2000);
				_hideTimeSettingLock = true;
			}
		}
		
		/**
		 * 
		 * @param event
		 * 跳转到下一页
		 * 
		 */		
		private function loopTimerTickHandler(event:TimerEvent):void
		{
			gotoNextPage();
		}
		
		// fullscreen button click handler
		private function onFullScreenBtnClick(e:MouseEvent):void
		{
			stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
			_bottomBar.fullscreenBtn.visible = false;
			_bottomBar.quitFullscreenBtn.visible = true;
			this.width = Capabilities.screenResolutionX;
			this.height = Capabilities.screenResolutionY;
			this.x=0;
			this.y=0;
		}
		
		// quit fullscreen button click handler
		private function onQuitFullScreenBtnClick(e:MouseEvent):void
		{
			stage.displayState = StageDisplayState.NORMAL;
			_bottomBar.fullscreenBtn.visible = true;
			_bottomBar.quitFullscreenBtn.visible = false;
			
		}
		
		// update screen size after exit fullscreen state
		public function updateScale():void
		{
			this.width = 1000;
			this.height = 625;
			_bottomBar.fullscreenBtn.visible = true;
			_bottomBar.quitFullscreenBtn.visible = false;
			stage.displayState = StageDisplayState.NORMAL;
		}
		
		
		/*****************************************************************************
		 *
		 * 建立连接，创建视频流
		 * 
		 *****************************************************************************/		
		private function connect():void
		{
			_ncContainer[_curPageStartIndex] = new NetConnection();
			_ncContainer[_curPageStartIndex].client = this;
			_ncContainer[_curPageStartIndex].addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			_ncContainer[_curPageStartIndex].addEventListener(IOErrorEvent.IO_ERROR, onIOError);
			_ncContainer[_curPageStartIndex].connect("rtmp://localhost/vod"); 
		}
		
		public function onBWDone():void{}
		
		protected function onIOError(event:IOErrorEvent):void
		{
			trace (event);
		}
		
		private function onNetStatus(event:NetStatusEvent):void
		{
			var type:String = event.info["code"];
			switch (type)
			{
				case "NetConnection.Connect.Success":
					trace (type);
					initNetStream();
					break;
				case "NetConnection.Connect.Closed":
					trace (type);
					break;
				default:
					break;
			}
		}
		
		/**
		 *
		 * 添加视频流 
		 * 
		 */		
		private function initNetStream():void
		{
			trace ("initNetStream" + _curPageStartIndex);
			
			_nsContainer[_curPageStartIndex] = new NetStream(_ncContainer[_curPageStartIndex]);  
			_nsContainer[_curPageStartIndex].bufferTime = 5;
			_client.onMetaData = onMetaData;
			_client.onPlayStatus = forNsStatus; 
			_nsContainer[_curPageStartIndex].client = _client; 
			_nsContainer[_curPageStartIndex].inBufferSeek = true;
			_nsContainer[_curPageStartIndex].soundTransform = new SoundTransform(0);
			_nsContainer[_curPageStartIndex].addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			_nsContainer[_curPageStartIndex].addEventListener(IOErrorEvent.IO_ERROR, onIOError);
			_videoBox[_curPageStartIndex].attachNetStream(_nsContainer[_curPageStartIndex]);
			_nsContainer[_curPageStartIndex].play("mp4:" + this._liveData[_curPageLiveContainerIndex].liveVO[this._curContainerVideoIndex].liveSDURL);
			//_nsContainer[_curPageStartIndex].pause();
			//_nsContainer[_curPageStartIndex].seek(0);  
			_loadTimerLock = false;
			_curPageStartIndex++;
			_curContainerVideoIndex++;
			
			trace ("_curPageStartIndex : " + _curPageStartIndex);
			
			if (this._curContainerVideoIndex == this._curContainerVideoCount)
			{
				this._curContainerIndex++;
				this._curPageLiveContainerIndex++;
				this._curContainerVideoIndex = 0;
				if (this._curPageStartIndex <= this._curPageEndIndex)
				{
					this._curContainerVideoCount = this._liveData[_curPageLiveContainerIndex].liveVO.length;
				}	
			}
		}
		
		private function onMetaData(metadata:Object):void
		{
			
		}
		
		private function forNsStatus(info:Object):void
		{
			if (info.code == "NetStream.Play.Complete")
			{
				trace(info.code);
			}
		}
		
		
		/**
		 *
		 * 移除播放器界面、事件监听等 
		 * 
		 */		
		private function clear():void
		{
			// stop netstream/netconnection, remove event listener
			for (var i:int=0; i < this._liveCount; i++)
			{
				if (_nsContainer[i])
				{
					_nsContainer[i].pause();
					_nsContainer[i].close();
					_nsContainer[i].removeEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
					_nsContainer[i].removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
					_nsContainer[i].soundTransform = null;
					_nsContainer[i] = null;
				}
				
				if (_ncContainer[i]) 
				{
					_ncContainer[i].close();
					_ncContainer[i].removeEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
					_ncContainer[i].removeEventListener(IOErrorEvent.IO_ERROR, onIOError);
					_ncContainer[i] = null;
				}
			}
			
			// remove video
			if (this._videoContainer)
			{
				for (var j:int=0; j < this._videoContainer.length; j++)
				{
					if (_videoContainer[j])
					{
						var _length:int = _videoContainer[j].numChildren;
						for (var k:int=0; k < _length; k++)
						{
							_videoContainer[j].removeChildAt(0);
							if (_videoContainer[j].numChildren == 0)
							{
								this.removeChild(_videoContainer[j]);
								_videoContainer[j] = null;
							}
						}
					}
				}
			}
			
			// remove event listener
			if (this._isFourScreenInterface)
			{
				_fourUI.playerUI1.removeEventListener(MouseEvent.CLICK, onFourClick);
				_fourUI.playerUI2.removeEventListener(MouseEvent.CLICK, onFourClick);
				_fourUI.playerUI3.removeEventListener(MouseEvent.CLICK, onFourClick);
				_fourUI.playerUI4.removeEventListener(MouseEvent.CLICK, onFourClick);
				_fourUI.playerUI1.removeEventListener(MouseEvent.MOUSE_OVER, onFourPlayerUIMouseOver);
				_fourUI.playerUI1.removeEventListener(MouseEvent.MOUSE_OUT, onFourPlayerUIMouseOut);
				_fourUI.playerUI2.removeEventListener(MouseEvent.MOUSE_OVER, onFourPlayerUIMouseOver);
				_fourUI.playerUI2.removeEventListener(MouseEvent.MOUSE_OUT, onFourPlayerUIMouseOut);
				_fourUI.playerUI3.removeEventListener(MouseEvent.MOUSE_OVER, onFourPlayerUIMouseOver);
				_fourUI.playerUI3.removeEventListener(MouseEvent.MOUSE_OUT, onFourPlayerUIMouseOut);
				_fourUI.playerUI4.removeEventListener(MouseEvent.MOUSE_OVER, onFourPlayerUIMouseOver);
				_fourUI.playerUI4.removeEventListener(MouseEvent.MOUSE_OUT, onFourPlayerUIMouseOut);
			}
			else
			{
				_nineUI.playerUI1.removeEventListener(MouseEvent.CLICK, onNineClick);
				_nineUI.playerUI2.removeEventListener(MouseEvent.CLICK, onNineClick);
				_nineUI.playerUI3.removeEventListener(MouseEvent.CLICK, onNineClick);
				_nineUI.playerUI4.removeEventListener(MouseEvent.CLICK, onNineClick);
				_nineUI.playerUI5.removeEventListener(MouseEvent.CLICK, onNineClick);
				_nineUI.playerUI6.removeEventListener(MouseEvent.CLICK, onNineClick);
				_nineUI.playerUI7.removeEventListener(MouseEvent.CLICK, onNineClick);
				_nineUI.playerUI8.removeEventListener(MouseEvent.CLICK, onNineClick);
				_nineUI.playerUI9.removeEventListener(MouseEvent.CLICK, onNineClick);
				_nineUI.playerUI1.removeEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
				_nineUI.playerUI1.removeEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
				_nineUI.playerUI2.removeEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
				_nineUI.playerUI2.removeEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
				_nineUI.playerUI3.removeEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
				_nineUI.playerUI3.removeEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
				_nineUI.playerUI4.removeEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
				_nineUI.playerUI4.removeEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
				_nineUI.playerUI5.removeEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
				_nineUI.playerUI5.removeEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
				_nineUI.playerUI6.removeEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
				_nineUI.playerUI6.removeEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
				_nineUI.playerUI7.removeEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
				_nineUI.playerUI7.removeEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
				_nineUI.playerUI8.removeEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
				_nineUI.playerUI8.removeEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
				_nineUI.playerUI9.removeEventListener(MouseEvent.MOUSE_OVER, onNinePlayerMouseOver);
				_nineUI.playerUI9.removeEventListener(MouseEvent.MOUSE_OUT, onNinePlayerMouseOut);
			}
			
			// remove interface 
			if (_fourUI)
			{
				if (this.contains(_fourUI))
				{
					this.removeChild(_fourUI);
					_fourUI = null;
				}
			}
			
			if (_nineUI)
			{
				if (this.contains(_nineUI))
				{
					this.removeChild(_nineUI);
					_nineUI = null;
				}
			}
			
			// stop time update timer
			_updateVideoTimeTimer.stop();
			_updateVideoTimeTimer.removeEventListener(TimerEvent.TIMER, onUpdateVideoTimeTimer);
		}
		
		/**
		 * 
		 * @param value : 页码文本框显示的内容
		 * 
		 */		
		public function set pageNumberText(value:String):void
		{
			this._bottomBar.pageNumberTxt.text = value;
		}
		
		/**
		 * 
		 * @return 返回当前所在的页数 
		 * 
		 */		
		private function getPageNumByCurPageMinLiveContainerIndex():int
		{
			var _index:int = 0;
			if (this._isFourScreenInterface)
			{
				for (var i:int=0; i < this._totalPageNumOfFour; i++)
				{
					if (this._curPageMinLiveContainerIndex >= (4 * i - 1))
					{
						_index++;
					}
				}
			}
			else
			{
				for (var j:int=0; j < this._totalPageNumOfNine; j++)
				{
					if (this._curPageMinLiveContainerIndex >= (9 * j - 1)) 
					{
						_index++;
					}
				}
			}
			return _index;
		}
		
		/**
		 * 
		 * @return 返回当前页最大索引
		 * 
		 */		
		private function getEndIndexByCurPageMinIndex():int
		{
			var index:int = 0;
			if (this._isFourScreenInterface)
			{
				if (_curPageNumOfFour >= _totalPageNumOfFour)
					index = this._liveCount - 1;
				else
					index = this._curPageStartIndex + 8; 
			}
			else
			{
				if (_curPageNumOfNine >= _totalPageNumOfNine)
					index = this._liveCount - 1;
				else
					index = this._curPageStartIndex + 15; 
			}
			return index;
		}
		
		/**
		 * 
		 * @param type
		 * @param listener
		 * @param useCapture
		 * @param priority
		 * @param useWeakReference
		 * 
		 */		
		override public function addEventListener(type:String, listener:Function, useCapture:Boolean=false, priority:int=0, useWeakReference:Boolean=false):void
		{
			_list.push([type,listener,useCapture])
			super.addEventListener(type,listener,useCapture,priority,useWeakReference)
		}
		
		private function destroy(e:Event):void
		{
			if(e.currentTarget != e.target)return;
			
			//删除子对象
			trace("删除前有子对象",numChildren)
			while(numChildren > 0)
			{
				removeChildAt(0);
			}
			trace("删除后有子对象",numChildren);
			
			//删除动态属性
			for(var k:String in this){
				trace("删除属性",k)
				delete this[k]
			}
			
			//删除侦听
			trace("删除前注册事件数:" + _list.length)
			for(var i:uint=0;i<_list.length;i++){
				trace("删除Listener",_list[i][0])
				removeEventListener(_list[i][0],_list[i][1],_list[i][2])
			}
			_list = null;
		}
	}
}
