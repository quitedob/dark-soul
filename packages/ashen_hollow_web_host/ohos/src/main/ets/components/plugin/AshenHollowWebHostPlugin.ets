import {
  Any,
  EventChannel,
  EventSink,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  StreamHandler
} from '@ohos/flutter_ohos';
import WebHostPlatformViewFactory, {
  WebHostEventEmitter,
  WebHostPlatformView
} from './WebHostPlatformView';

const VIEW_TYPE: string = 'ashen_hollow/web_host';
const METHOD_CHANNEL: string = 'ashen_hollow/web_host/methods';
const EVENT_CHANNEL: string = 'ashen_hollow/web_host/events';
const PROTOCOL_VERSION: number = 1;

export default class AshenHollowWebHostPlugin
  implements FlutterPlugin, MethodCallHandler, StreamHandler, WebHostEventEmitter {
  private methodChannel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  private eventSink: EventSink | null = null;
  private readonly views: Map<number, WebHostPlatformView> =
    new Map<number, WebHostPlatformView>();

  getUniqueClassName(): string {
    return 'AshenHollowWebHostPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.methodChannel =
      new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
    this.methodChannel.setMethodCallHandler(this);
    this.eventChannel =
      new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL);
    this.eventChannel.setStreamHandler(this);
    const registered: boolean = binding.getPlatformViewRegistry()
      .registerViewFactory(
        VIEW_TYPE,
        new WebHostPlatformViewFactory(this.views, this)
      );
    if (!registered) {
      throw new Error(`Platform view type ${VIEW_TYPE} is already registered.`);
    }
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.methodChannel?.setMethodCallHandler(null);
    this.eventSink = null;
    this.views.forEach((view: WebHostPlatformView) => view.dispose());
    this.views.clear();
    this.methodChannel = null;
    this.eventChannel = null;
  }

  onListen(args: Any, events: EventSink): void {
    this.eventSink = events;
  }

  onCancel(args: Any): void {
    this.eventSink = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    try {
      const args: Map<string, Object> = call.args as Map<string, Object>;
      const version: number = args?.get('protocolVersion') as number ?? 0;
      if (version !== PROTOCOL_VERSION) {
        result.error(
          'unsupported_protocol',
          `Expected protocol ${PROTOCOL_VERSION}, got ${version}.`,
          null
        );
        return;
      }
      const viewId: number = args?.get('viewId') as number ?? -1;
      const view: WebHostPlatformView | undefined = this.views.get(viewId);
      if (view === undefined) {
        result.error('unknown_view', `No web host exists for view ${viewId}.`, null);
        return;
      }
      switch (call.method) {
        case 'attach':
          result.success(null);
          return;
        case 'load':
          view.load(args.get('source') as string);
          result.success(null);
          return;
        case 'pause':
          view.pause();
          result.success(null);
          return;
        case 'resume':
          view.resume();
          result.success(null);
          return;
        case 'sendBridgeJson':
          view.sendBridgeJson(args.get('json') as string);
          result.success(null);
          return;
        case 'dispose':
          view.dispose();
          this.views.delete(viewId);
          result.success(null);
          return;
        default:
          result.notImplemented();
      }
    } catch (error) {
      result.error('web_host_error', `${error}`, null);
    }
  }

  emit(
    viewId: number,
    event: string,
    payload?: Map<string, Object>,
    bridgeJson?: string
  ): void {
    const message: Map<string, Object> = new Map<string, Object>();
    message.set('protocolVersion', PROTOCOL_VERSION);
    message.set('viewId', viewId);
    message.set('event', event);
    if (payload !== undefined) {
      message.set('payload', payload);
    }
    if (bridgeJson !== undefined) {
      message.set('bridgeJson', bridgeJson);
    }
    this.eventSink?.success(message);
  }
}
