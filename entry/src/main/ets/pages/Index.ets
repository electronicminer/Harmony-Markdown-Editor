import { Markdown } from '@lidary/markdown';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { router } from '@kit.ArkUI'; 
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { AIConfigClass } from '../utils/AIConfig';
import { AIService } from '../utils/AIService';

// 明确声明 Promise 返回值的接口，防止被推导为 any/unknown
interface AIConnectionResult {
  success: boolean;
  content?: string;
  error?: string;
}

/**
 * AI 配置对话框
 */
@CustomDialog
struct AIConfigDialog {
  controller: CustomDialogController;
  @Link aiApiUrl: string;
  @Link aiApiKey: string;
  @Link aiModel: string;
  @Link aiSystemPrompt: string;
  @Link aiEnabled: boolean;
  @Link isDark: boolean;
  onConfigSaved: () => void = () => {};

  @State isTesting: boolean = false;
  @State testResult: string = '';

  build() {
    Column() {
      Text('AI 配置')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000') // 适配深色模式
        .margin({ top: 24, bottom: 24 })

      Column({ space: 16 }) {
        // API URL
        Column() {
          Text('API URL')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
            .margin({ bottom: 8 })
          TextInput({ text: this.aiApiUrl, placeholder: 'https://api.xxx.cn/v1/chat/completions' })
            .fontSize(15)
            .width('100%')
            .height(48)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
            .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
            .borderRadius(12)
            .onChange((value: string) => {
              this.aiApiUrl = value;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // API Key
        Column() {
          Text('API Key')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
            .margin({ bottom: 8 })
          TextInput({ text: this.aiApiKey, placeholder: 'sk-...' })
            .fontSize(15)
            .width('100%')
            .height(48)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
            .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
            .borderRadius(12)
            .type(InputType.Password)
            .onChange((value: string) => {
              this.aiApiKey = value;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // Model
        Column() {
          Text('模型名称')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
            .margin({ bottom: 8 })
          TextInput({ text: this.aiModel, placeholder: 'gpt-3.5-turbo' })
            .fontSize(15)
            .width('100%')
            .height(48)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
            .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
            .borderRadius(12)
            .onChange((value: string) => {
              this.aiModel = value;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 系统提示词
        Column() {
          Text('系统提示词')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
            .margin({ bottom: 8 })
          TextArea({ text: this.aiSystemPrompt })
            .fontSize(15)
            .width('100%')
            .height(100)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
            .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
            .borderRadius(12)
            .onChange((value: string) => {
              this.aiSystemPrompt = value;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .padding({ left: 24, right: 24 })
      .width('100%')

      // 测试结果
      if (this.testResult) {
        Row() {
          Text(this.testResult)
            .fontSize(14)
            .fontColor(this.testResult.startsWith('✅') ? '#00A854' : '#F4222D')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 16 })
      }

      // 按钮
      Row({ space: 16 }) {
        Button('测试连接')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDark ? '#E5FFFFFF' : '#0A59F7')
          .backgroundColor(this.isDark ? '#33FFFFFF' : 'rgba(10, 89, 247, 0.1)')
          .type(ButtonType.Capsule)
          .layoutWeight(1)
          .height(48)
          .onClick(() => {
            this.testConnection();
          })

        Button('保存')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor('#0A59F7')
          .type(ButtonType.Capsule)
          .layoutWeight(1)
          .height(48)
          .onClick(() => {
            this.aiEnabled = true;
            this.onConfigSaved();
            this.controller.close();
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24 })
      .justifyContent(FlexAlign.Center)
    }
    .backgroundColor(this.isDark ? '#242424' : '#FFFFFF')
    .borderRadius(32)
    .width('92%')
    .padding({ bottom: 24 })
  }

  async testConnection() {
    this.isTesting = true;
    this.testResult = '测试中...';
    
    const config: AIConfigClass = new AIConfigClass();
    config.apiUrl = this.aiApiUrl;
    config.apiKey = this.aiApiKey;
    config.model = this.aiModel;
    config.systemPrompt = this.aiSystemPrompt;
    
    // 强制转换为明确的接口类型
    AIService.testConnection(config).then((res: Object) => {
      const result = res as AIConnectionResult;
      if (result.success) {
        this.testResult = '✅ 成功：' + (result.content?.substring(0, 50) || '连接正常');
      } else {
        this.testResult = '❌ 失败：' + (result.error || '未知错误');
      }
      this.isTesting = false;
    }).catch((e: object) => {
      const errorMsg: string = e instanceof Error ? (e as Error).message : String(e);
      this.testResult = '❌ 异常：' + errorMsg;
      this.isTesting = false;
    });
  }
}

@CustomDialog
struct SettingsDialog {
  controller: CustomDialogController;
  @Link isDark: boolean;
  @Link openLastFile: boolean;
  @Link autoSave: boolean;
  @Link autoSaveInterval: number;
  @Link defaultViewMode: number;
  @Link followSystem: boolean;
  @Link aiApiUrl: string;
  @Link aiApiKey: string;
  @Link aiModel: string;
  @Link aiSystemPrompt: string;
  @Link aiEnabled: boolean;
  confirm: () => void = () => {};
  aiDialogController: CustomDialogController | undefined;

  build() {
    Column() {
      Text('设置')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
        .margin({ top: 24, bottom: 24 })

      Column() {
        Row() {
          Text('默认视图模式')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
            .layoutWeight(1)
          Select([{ value: '分屏对比' }, { value: '仅编辑' }, { value: '仅预览' }])
            .selected(this.defaultViewMode)
            .value(this.defaultViewMode === 0 ? '分屏对比' : (this.defaultViewMode === 1 ? '仅编辑' : '仅预览'))
            .font({ size: 16, weight: FontWeight.Medium })
            .fontColor(this.isDark ? '#0A59F7' : '#0A59F7')
            .backgroundColor('transparent')
            .onSelect((index: number) => {
              this.defaultViewMode = index;
            })
        }
        .width('100%')
        .height(56)

        Divider().color(this.isDark ? '#1AFFFFFF' : '#0D000000')

        Row() {
          Text('跟随系统深色模式')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.followSystem })
            .selectedColor('#0A59F7')
            .onChange((isOn: boolean): void => {
              this.followSystem = isOn;
            })
        }
        .width('100%')
        .height(56)

        Divider().color(this.isDark ? '#1AFFFFFF' : '#0D000000')

        Row() {
          Text('深色模式')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
            .layoutWeight(1)
            .opacity(this.followSystem ? 0.4 : 1)
          Toggle({ type: ToggleType.Switch, isOn: this.isDark })
            .selectedColor('#0A59F7')
            .enabled(!this.followSystem)
            .onChange((isOn: boolean): void => {
              this.isDark = isOn;
            })
        }
        .width('100%')
        .height(56)

        Divider().color(this.isDark ? '#1AFFFFFF' : '#0D000000')

        Row() {
          Text('启动时打开上次文件')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.openLastFile })
            .selectedColor('#0A59F7')
            .onChange((isOn: boolean): void => {
              this.openLastFile = isOn;
            })
        }
        .width('100%')
        .height(56)

        Divider().color(this.isDark ? '#1AFFFFFF' : '#0D000000')

        Row() {
          Text('自动保存')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.autoSave })
            .selectedColor('#0A59F7')
            .onChange((isOn: boolean): void => {
              this.autoSave = isOn;
            })
        }
        .width('100%')
        .height(56)

        if (this.autoSave) {
          Divider().color(this.isDark ? '#1AFFFFFF' : '#0D000000')
          Row() {
            Text('自动保存间隔 (秒)')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
              .layoutWeight(1)
            TextInput({ text: this.autoSaveInterval.toString() })
              .type(InputType.Number)
              .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
              .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
              .width(80)
              .height(36)
              .borderRadius(8)
              .onChange((value: string) => {
                const val: number = parseInt(value);
                if (!Number.isNaN(val) && val > 0) {
                  this.autoSaveInterval = val;
                }
              })
          }
          .width('100%')
          .height(56)
        }

        Divider().color(this.isDark ? '#1AFFFFFF' : '#0D000000')

        Row() {
          Column() {
            Text('AI 配置')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
            Text('配置 AI 助手 API')
              .fontSize(13)
              .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          
          Button('去配置')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#0A59F7')
            .backgroundColor(this.isDark ? '#33FFFFFF' : 'rgba(10, 89, 247, 0.1)')
            .type(ButtonType.Capsule)
            .height(36)
            .onClick(() => {
              if (this.aiDialogController) {
                this.aiDialogController.open();
              }
            })
        }
        .width('100%')
        .height(72)
      }
      .padding({ left: 24, right: 24 })
      .backgroundColor(this.isDark ? '#2A2A2A' : '#F7F7F7')
      .borderRadius(20)
      .margin({ left: 24, right: 24 })

      Button('确定')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor('#0A59F7')
        .type(ButtonType.Capsule)
        .height(48)
        .onClick(() => {
          this.confirm();
          this.controller.close();
        })
        .margin({ top: 24, bottom: 24 })
        .width('80%')
    }
    .backgroundColor(this.isDark ? '#242424' : '#FFFFFF') 
    .borderRadius(32)
    .width('92%')
  }
}

@Entry
@Component
struct Index {
  @State text: string = '';
  @State isDark: boolean = false;
  @State isLoading: boolean = true;
  @State openLastFile: boolean = false;
  @State autoSave: boolean = false;
  @State autoSaveInterval: number = 60;
  @State defaultViewMode: number = 0;
  @State @Watch('onFollowSystemChange') followSystem: boolean = false;
  @StorageProp('currentColorMode') @Watch('onSystemModeChange') currentSystemMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  private fileUri: string = '';
  
  // AI 配置状态
  @State aiApiUrl: string = '';
  @State aiApiKey: string = '';
  @State aiModel: string = 'gpt-3.5-turbo';
  @State aiSystemPrompt: string = '你是一个专业的 Markdown 写作助手，擅长解答 Markdown 语法问题、提供写作建议和生成各种 Markdown 模板。请用简洁清晰的中文回答用户问题。';
  @State aiEnabled: boolean = false;
  
  // 核心修复：直接在类属性处初始化对话框控制器，编译器就能正确解析 $ 语法
// 1. AI 配置弹窗控制器
  aiDialogController: CustomDialogController = new CustomDialogController({
    builder: AIConfigDialog({
      aiApiUrl: $aiApiUrl,
      aiApiKey: $aiApiKey,
      aiModel: $aiModel,
      aiSystemPrompt: $aiSystemPrompt,
      aiEnabled: $aiEnabled,
      isDark: $isDark,
      onConfigSaved: () => {
        this.saveAIConfig();
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true // ✅ 加上这行，去除系统默认白底
  });

  // 2. 设置弹窗控制器
  dialogController: CustomDialogController = new CustomDialogController({
    builder: SettingsDialog({
      isDark: $isDark,
      openLastFile: $openLastFile,
      autoSave: $autoSave,
      autoSaveInterval: $autoSaveInterval,
      defaultViewMode: $defaultViewMode,
      followSystem: $followSystem,
      aiApiUrl: $aiApiUrl,
      aiApiKey: $aiApiKey,
      aiModel: $aiModel,
      aiSystemPrompt: $aiSystemPrompt,
      aiEnabled: $aiEnabled,
      confirm: () => {
        this.savePreferences();
      },
      aiDialogController: this.aiDialogController
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true // ✅ 加上这行，去除系统默认白底
  });
  
  onFollowSystemChange() {
    if (this.followSystem) {
      this.isDark = this.currentSystemMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
  }

  onSystemModeChange() {
    if (this.followSystem) {
      this.isDark = this.currentSystemMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
  }

  async aboutToAppear() {
    // 这里不再初始化 Controller，直接走业务逻辑
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    
    try {
      this.isDark = await PreferencesUtil.getIsDark(context);
      this.openLastFile = await PreferencesUtil.getOpenLastFile(context);
      this.autoSave = await PreferencesUtil.getAutoSave(context);
      this.autoSaveInterval = await PreferencesUtil.getAutoSaveInterval(context);
      this.defaultViewMode = await PreferencesUtil.getDefaultViewMode(context);
      this.followSystem = await PreferencesUtil.getFollowSystem(context);
    } catch (err) {
      console.error('Failed to load preferences');
    }

    if (this.followSystem) {
      this.isDark = this.currentSystemMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    
    if (this.openLastFile) {
      try {
        const lastUri: string = await PreferencesUtil.getLastFileUri(context);
        if (lastUri) {
          await this.loadUri(lastUri);
        } else {
          this.readFile(context);
        }
      } catch (err) {
        this.readFile(context);
      }
    } else {
      this.readFile(context);
    }
    
    await this.loadAIConfig();
  }

  async savePreferences() {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await PreferencesUtil.saveIsDark(context, this.isDark);
      await PreferencesUtil.saveOpenLastFile(context, this.openLastFile);
      await PreferencesUtil.saveAutoSave(context, this.autoSave);
      await PreferencesUtil.saveAutoSaveInterval(context, this.autoSaveInterval);
      await PreferencesUtil.saveDefaultViewMode(context, this.defaultViewMode);
      await PreferencesUtil.saveFollowSystem(context, this.followSystem);
    } catch (err) {
      console.error('Failed to save preferences');
    }
  }

  async saveAIConfig() {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await PreferencesUtil.saveAIConfigApiUrl(context, this.aiApiUrl);
      await PreferencesUtil.saveAIConfigApiKey(context, this.aiApiKey);
      await PreferencesUtil.saveAIConfigModel(context, this.aiModel);
      await PreferencesUtil.saveAIConfigSystemPrompt(context, this.aiSystemPrompt);
      await PreferencesUtil.saveAIConfigEnabled(context, this.aiEnabled);
    } catch (err) {
      console.error('Failed to save AI config');
    }
  }

  async loadAIConfig() {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      this.aiApiUrl = await PreferencesUtil.getAIConfigApiUrl(context);
      this.aiApiKey = await PreferencesUtil.getAIConfigApiKey(context);
      this.aiModel = await PreferencesUtil.getAIConfigModel(context);
      this.aiSystemPrompt = await PreferencesUtil.getAIConfigSystemPrompt(context);
      this.aiEnabled = await PreferencesUtil.getAIConfigEnabled(context);
    } catch (err) {
      console.error('Failed to load AI config');
    }
  }

  onPageShow(): void {
    // 修复 ArkTS 类型推导报错：明确 Record 类型以消除隐式 any
    const params = router.getParams() as Record<string, Object> | undefined;
    if (params) {
      if (params['content'] !== undefined) {
        this.text = params['content'] as string;
      }
      if (params['uri'] !== undefined) {
        this.fileUri = params['uri'] as string;
      }
    }
  }

  readFile(context: common.UIAbilityContext) {
    try {
      context.resourceManager.getRawFileContent('mark_test.md', (error: BusinessError, value: Uint8Array) => {
        if (error != null) {
          console.error('error is ' + error.message);
        } else {
          const textDecoder: util.TextDecoder = new util.TextDecoder();
          this.text = textDecoder.decodeToString(value);
        }
      });
    } catch (error) {
      // 修复 ArkTS 报错：catch 捕获的对象在严格模式下必须明确转换为业务错误类
      const e = error as BusinessError;
      console.error('readFile error: ' + e.message);
    }
  }

  async loadUri(uri: string) {
    try {
      this.isLoading = true;
      this.fileUri = uri;
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const buf: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      
      const textDecoder: util.TextDecoder = new util.TextDecoder();
      const content: string = textDecoder.decodeToString(new Uint8Array(buf));
      
      this.text = content;
      this.isLoading = false;
    } catch (error) {
      const e = error as BusinessError;
      console.error('Load file failed:', e.message);
      this.isLoading = false;
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.readFile(context);
    }
  }

  async openFile() {
    try {
      const documentViewPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker();
      const documentSelectOptions: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      
      const result: Array<string> = await documentViewPicker.select(documentSelectOptions);
      if (result && result.length > 0) {
        const uri: string = result[0];
        await this.loadUri(uri);
        
        if (this.openLastFile) {
          const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
          await PreferencesUtil.saveLastFileUri(context, uri);
        }
      }
    } catch (error) {
      const e = error as BusinessError;
      console.error('Open file failed:', e.message);
      this.isLoading = false;
    }
  }

  @Builder
  GlassButton(icon: string, action: () => void, isPrimary: boolean = false, fontSize: number = 20) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      Text(icon)
        .fontSize(fontSize)
        .fontColor(isPrimary ? Color.White : (this.isDark ? '#E5FFFFFF' : '#E5000000'))
        .fontWeight(FontWeight.Medium)
    }
    .width(44)
    .height(44)
    .backgroundColor(isPrimary ? '#0A59F7' : (this.isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.05)'))
    .backdropBlur(50)
    .shadow(isPrimary ? ShadowStyle.OUTER_DEFAULT_SM : ShadowStyle.OUTER_DEFAULT_XS)
    .onClick(action)
    .animation({ duration: 200, curve: Curve.EaseInOut })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // 底层：可以自由滚动的 Markdown 内容
      Scroll() {
        Column() {
          // 占位符：给顶部的玻璃胶囊让出初始位置
          Row().height(96).width('100%')

          Markdown({
            content: this.text,
            options: {
              darkMode: this.isDark,
              options: {
                gfm: true
              },
              darkTheme: {
                themeColor: Color.Orange
              },
              imageClick: (url?: string) => {
                try {
                  this.getUIContext().getPromptAction().showToast({
                    message: '图片被点击:' + url,
                    duration: 1500
                  });
                } catch (error) {
                  console.error('Toast failed');
                }
              },
              linkClick: (url?: string) => {
                try {
                  this.getUIContext().getPromptAction().showToast({
                    message: '超链接被点击----url:' + url,
                    duration: 1500
                  });
                } catch (error) {
                  console.error('Toast failed');
                }
              }
            },
            onLoading: () => {
              this.isLoading = true;
            },
            onError: () => {
              this.isLoading = false;
            },
            onSuccess: () => {
              this.isLoading = false;
            }
          })
          .padding({ left: 16, right: 16, bottom: 40 })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.isDark ? '#000000' : '#F1F3F5')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .scrollBar(BarState.Auto)

      // 顶层：悬浮的玻璃状态栏/导航栏
      Row() {
        Text('鸿蒙 Markdown')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontFamily('HarmonyOS Sans')
          .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          .layoutWeight(1)

        Row({ space: 12 }) {
          // 设置
          this.GlassButton('⚙️', () => {
            if (this.dialogController) {
              this.dialogController.open();
            }
          });

          // 主题切换
          this.GlassButton(this.isDark ? '☀️' : '🌙', () => {
            if (this.followSystem) {
              this.followSystem = false;
            }
            this.isDark = !this.isDark;
            this.savePreferences();
          });

          // 打开文件
          this.GlassButton('📂', () => {
            this.openFile();
          });

          // 新建文件
          this.GlassButton('+', () => {
            try {
              router.pushUrl({
                url: 'pages/Editor',
                params: {
                  content: '# ',
                  uri: '',
                  isDark: this.isDark,
                  viewMode: this.defaultViewMode
                }
              });
            } catch (error) {
              const e = error as BusinessError;
              console.error('pushUrl error: ' + e.message);
            }
          }, false, 24);

          // 编辑当前文件
          this.GlassButton('✏️', () => {
            try {
              router.pushUrl({
                url: 'pages/Editor',
                params: {
                  content: this.text,
                  uri: this.fileUri,
                  isDark: this.isDark,
                  viewMode: this.defaultViewMode
                }
              });
            } catch (error) {
              const e = error as BusinessError;
              console.error('pushUrl error: ' + e.message);
            }
          }, true);
        }
      }
      .width('92%')
      .padding({ left: 24, right: 24, top: 16, bottom: 16 })
      .margin({ top: 24 }) 
      .borderRadius(32) 
      .backgroundColor(this.isDark ? 'rgba(0, 0, 0, 0.4)' : 'rgba(241, 243, 245, 0.5)')
      .backdropBlur(80) 
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .zIndex(10)

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .size({ width: 48, height: 48 })
            .color('#0A59F7')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .zIndex(100)
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}