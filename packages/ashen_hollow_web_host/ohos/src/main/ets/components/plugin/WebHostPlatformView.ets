import common from '@ohos.app.ability.common';
import webview from '@ohos.web.webview';
import {
  Any,
  PlatformView,
  PlatformViewFactory,
  StandardMessageCodec
} from '@ohos/flutter_ohos';
import { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';

const PROTOCOL_VERSION: number = 1;

export interface WebHostEventEmitter {
  emit(viewId: number, event: string, payload?: Map<string, Object>, bridgeJson?: string): void;
}

class JavaScriptBridge {
  constructor(
    private readonly viewId: number,
    private readonly emitter: WebHostEventEmitter
  ) {
  }

  postMessage(message: string): void {
    this.emitter.emit(this.viewId, 'bridgeMessage', undefined, message);
  }
}

@Builder
function WebHostBuilder(params: Params) {
  Web({
    src: (params.platformView as WebHostPlatformView).getSource(),
    controller: (params.platformView as WebHostPlatformView).getController()
  })
    .javaScriptAccess(true)
    .domStorageAccess(true)
    .fileAccess(true)
    .javaScriptProxy({
      object: (params.platformView as WebHostPlatformView).getBridge(),
      name: 'AshenHollowHost',
      methodList: ['postMessage'],
      controller: (params.platformView as WebHostPlatformView).getController()
    })
    .onPageEnd(() => {
      (params.platformView as WebHostPlatformView).notifyReady()
    })
    .onErrorReceive((event) => {
      (params.platformView as WebHostPlatformView).notifyError(
        event?.request?.getRequestUrl() ?? 'unknown',
        event?.error?.getErrorInfo() ?? 'Web component load failed'
      )
    })
}

export class WebHostPlatformView extends PlatformView {
  private readonly controller: webview.WebviewController = new webview.WebviewController();
  private readonly bridge: JavaScriptBridge;
  private source: string;
  private disposed: boolean = false;
  private readonly wrappedBuilder: WrappedBuilder<[Params]> = wrapBuilder(WebHostBuilder);

  constructor(
    private readonly viewId: number,
    initialSource: string,
    private readonly emitter: WebHostEventEmitter
  ) {
    super();
    this.source = initialSource;
    this.bridge = new JavaScriptBridge(viewId, emitter);
  }

  getView(): WrappedBuilder<[Params]> {
    return this.wrappedBuilder;
  }

  getController(): webview.WebviewController {
    return this.controller;
  }

  getBridge(): JavaScriptBridge {
    return this.bridge;
  }

  getSource(): string {
    return this.source;
  }

  load(source: string): void {
    this.ensureActive();
    this.source = source;
    this.controller.loadUrl(source);
  }

  pause(): void {
    if (!this.disposed) {
      this.controller.onInactive();
    }
  }

  resume(): void {
    if (!this.disposed) {
      this.controller.onActive();
    }
  }

  sendBridgeJson(json: string): void {
    this.ensureActive();
    const escaped: string = JSON.stringify(json);
    this.controller.runJavaScript(
      `window.AshenHollowBridge && window.AshenHollowBridge.receive(${escaped});`
    );
  }

  notifyReady(): void {
    this.emitter.emit(this.viewId, 'ready');
  }

  notifyError(source: string, message: string): void {
    const payload: Map<string, Object> = new Map<string, Object>();
    payload.set('source', source);
    payload.set('message', message);
    this.emitter.emit(this.viewId, 'error', payload);
  }

  dispose(): void {
    this.disposed = true;
  }

  private ensureActive(): void {
    if (this.disposed) {
      throw new Error(`Web host view ${this.viewId} is disposed.`);
    }
  }
}

export default class WebHostPlatformViewFactory extends PlatformViewFactory {
  constructor(
    private readonly views: Map<number, WebHostPlatformView>,
    private readonly emitter: WebHostEventEmitter
  ) {
    super(StandardMessageCodec.INSTANCE);
  }

  create(context: common.Context, viewId: number, args: Any): PlatformView {
    const params: Map<string, Object> = args as Map<string, Object>;
    const version: number = params?.get('protocolVersion') as number ?? 0;
    if (version !== PROTOCOL_VERSION) {
      throw new Error(`Unsupported bridge protocol version: ${version}`);
    }
    const source: string =
      params?.get('initialSource') as string ?? 'resource://rawfile/game/index.html';
    const view: WebHostPlatformView =
      new WebHostPlatformView(viewId, source, this.emitter);
    this.views.set(viewId, view);
    return view;
  }
}
