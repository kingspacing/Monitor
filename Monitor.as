package
{
	import flash.display.*;
	import flash.events.Event;
	import flash.events.FullScreenEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.system.Capabilities;
	import flash.ui.KeyLocation;
	import flash.ui.Keyboard;
	import flash.ui.KeyboardType;
	
	public class Monitor extends Sprite
	{
		private var _monitor:MonitorView; 
		private var _bg:Sprite = new Sprite();
		
		public function Monitor()
		{
			if (stage)
			{
				
				this.addEventListener(Event.ADDED_TO_STAGE, init);
			}
			else
			{
				init(null);
			}
		}
		
		private function init(event:Event = null):void
		{
			this.removeEventListener(Event.ADDED_TO_STAGE, init);
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			stage.displayState = StageDisplayState.NORMAL;
			stage.frameRate = 24;
			createBG();
			createMainView();
			stage.addEventListener(Event.RESIZE, onResize);
			stage.addEventListener(FullScreenEvent.FULL_SCREEN, onFullScreen);
			stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		}
		
		private function onFullScreen(event:FullScreenEvent):void
		{
			if (stage.displayState == StageDisplayState.NORMAL)
			{
				_monitor.updateScale();
				ReLayout();
			}
		}
		
		private function onKeyDown(event:KeyboardEvent):void
		{
			trace (event.keyCode);
		}
		
		private function onResize(event:Event):void
		{
			ReLayout();
		}
		
		private function ReLayout():void
		{
			if (_monitor)
			{
				if (this.contains(_monitor))
				{
					_monitor.x = (stage.stageWidth - _monitor.width) * 0.5;
					_monitor.y = (stage.stageHeight - _monitor.height) * 0.5;
				}
			}
		}
		
		private function createBG():void
		{
			_bg = new Sprite();
			_bg.graphics.beginFill(0x336699, 0.5);
			_bg.graphics.drawRect(0,0, Capabilities.screenResolutionX, Capabilities.screenResolutionY);
			_bg.graphics.endFill();
			this.addChild(_bg);
		}
		
		private function createMainView():void
		{
			if (_monitor == null)
			{
				_monitor = new MonitorView();
				_monitor.x = (stage.stageWidth - _monitor.width) * 0.5;
				_monitor.y = (stage.stageHeight - _monitor.height) * 0.5;
				this.addChild(_monitor);
			}
		}
	}
}
