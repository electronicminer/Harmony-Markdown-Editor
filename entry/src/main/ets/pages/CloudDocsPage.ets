import { promptAction, router } from '@kit.ArkUI';
import { AuthService } from '../utils/AuthService';
import { CloudDBService } from '../utils/CloudDBService';
import { UserDocument } from '../models/UserDocument';
import { ShareDialog } from '../components/ShareDialog';

@Entry
@Component
struct CloudDocsPage {
  @State myDocs: UserDocument[] = [];
  @State sharedDocs: UserDocument[] = [];
  @State activeTab: number = 0;
  @State isLoading: boolean = false;
  @State currentUserUid: string = '';
  @State importDocId: string = '';
  @State showImportDialog: boolean = false;
  @State isDark: boolean = false;
  @State isCloudConnected: boolean = false;
  @State selectedDoc: UserDocument = new UserDocument();

  private shareDialogController: CustomDialogController = new CustomDialogController({
    builder: ShareDialog({
      doc: this.selectedDoc,
      isDark: this.isDark,
      onRefresh: () => { this.loadDocuments(); }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['isDark'] !== undefined) {
      this.isDark = params['isDark'] as boolean;
    }
    CloudDBService.forceCloudMode();
    this.loadDocuments();
  }

  async loadDocuments(): Promise<void> {
    this.isLoading = true;
    await CloudDBService.init();
    this.isCloudConnected = !CloudDBService.isDemoMode;
    const user = await AuthService.getCurrentUser();
    if (!user) {
      promptAction.showToast({ message: '请先登录', duration: 2000 });
      this.isLoading = false;
      router.back();
      return;
    }
    this.currentUserUid = user.uid;

    const results = await Promise.all([
      CloudDBService.getMyDocuments(),
      CloudDBService.getSharedWithMe()
    ]);
    this.myDocs = results[0];
    this.sharedDocs = results[1];
    this.isLoading = false;
  }

  async handleImport(): Promise<void> {
    const trimmed = this.importDocId.trim();
    if (!trimmed) {
      promptAction.showToast({ message: '请输入文档ID', duration: 2000 });
      return;
    }

    this.isLoading = true;
    const doc = await CloudDBService.getDocumentById(trimmed);
    this.isLoading = false;

    if (!doc) {
      promptAction.showToast({ message: '未找到该文档', duration: 2000 });
      return;
    }

    const user = await AuthService.getCurrentUser();
    if (!user) {
      promptAction.showToast({ message: '请先登录', duration: 2000 });
      return;
    }

    if (!doc.isSharedWithUser(user.email) && doc.ownerId !== user.uid) {
      promptAction.showToast({ message: '该文档未分享给你', duration: 2000 });
      return;
    }

    this.showImportDialog = false;
    this.importDocId = '';
    router.pushUrl({
      url: 'pages/Editor',
      params: { content: doc.content, cloudDocId: doc.id, isDark: this.isDark }
    });
  }

  openDocument(doc: UserDocument): void {
    router.pushUrl({
      url: 'pages/Editor',
      params: { content: doc.content, cloudDocId: doc.id, isDark: this.isDark }
    });
  }

  async deleteDocument(doc: UserDocument): Promise<void> {
    const result = await CloudDBService.deleteDocument(doc);
    if (result.success) {
      promptAction.showToast({ message: result.message, duration: 1500 });
      await this.loadDocuments();
    } else {
      promptAction.showToast({ message: result.message, duration: 2000 });
    }
  }

  openShareDialog(doc: UserDocument): void {
    this.selectedDoc = doc;
    this.shareDialogController.open();
  }

  @Builder
  DocCard(doc: UserDocument, isOwner: boolean) {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Column() {
          Text(doc.getDisplayTitle().charAt(0).toUpperCase())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(44)
        .height(44)
        .borderRadius(14)
        .backgroundColor(isOwner ? '#0A59F7' : '#722ED1')
        .justifyContent(FlexAlign.Center)

        Column({ space: 4 }) {
          Text(doc.getDisplayTitle())
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: 8 }) {
            Text(doc.getFormattedDate())
              .fontSize(11)
              .fontColor(this.isDark ? '#66FFFFFF' : '#66000000')

            if (doc.isPublic) {
              Text('公开')
                .fontSize(10)
                .fontColor('#00A854')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(4)
                .backgroundColor('rgba(0,168,84,0.1)')
            }

            if (!isOwner) {
              Text('来自分享')
                .fontSize(10)
                .fontColor('#722ED1')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(4)
                .backgroundColor('rgba(114,46,209,0.1)')
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Row({ space: 8 }) {
        Button('打开')
          .fontSize(12)
          .fontColor('#0A59F7')
          .backgroundColor('rgba(10,89,247,0.1)')
          .type(ButtonType.Capsule)
          .height(32)
          .layoutWeight(1)
          .onClick(() => this.openDocument(doc))

        if (isOwner) {
          Button('分享')
            .fontSize(12)
            .fontColor('#722ED1')
            .backgroundColor('rgba(114,46,209,0.1)')
            .type(ButtonType.Capsule)
            .height(32)
            .layoutWeight(1)
            .onClick(() => this.openShareDialog(doc))

          Button('删除')
            .fontSize(12)
            .fontColor('#F4222D')
            .backgroundColor('rgba(244,34,45,0.1)')
            .type(ButtonType.Capsule)
            .height(32)
            .layoutWeight(1)
            .onClick(() => this.deleteDocument(doc))
        }
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .borderRadius(20)
    .backgroundColor(this.isDark ? 'rgba(255,255,255,0.06)' : 'rgba(10,89,247,0.04)')
  }

  @Builder
  TabButton(label: string, tabIndex: number, onClick: () => void) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.activeTab === tabIndex ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.activeTab === tabIndex ? '#0A59F7' : (this.isDark ? '#99FFFFFF' : '#99000000'))
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .borderRadius(20)
      .backgroundColor(this.activeTab === tabIndex ? 'rgba(10,89,247,0.1)' : 'transparent')
      .onClick(onClick)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        Row().height(100).width('100%')

        Row({ space: 12 }) {
          this.TabButton('我的文档', 0, () => { this.activeTab = 0; })
          this.TabButton('分享给我', 1, () => { this.activeTab = 1; })
          Blank()
          Button('导入')
            .fontSize(12)
            .fontColor('#0A59F7')
            .backgroundColor('rgba(10,89,247,0.1)')
            .type(ButtonType.Capsule)
            .height(32)
            .onClick(() => { this.showImportDialog = true; })
        }
        .width('92%')
        .margin({ bottom: 16 })

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .size({ width: 36, height: 36 })
              .color('#0A59F7')
          }
          .width('100%')
          .height(200)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 12 }) {
              if (this.activeTab === 0) {
                if (this.myDocs.length === 0) {
                  Column({ space: 8 }) {
                    Text('☁️')
                      .fontSize(40)
                    Text('还没有云端文档')
                      .fontSize(15)
                      .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
                    Text('在编辑器中点击云上传按钮保存到云端')
                      .fontSize(12)
                      .fontColor(this.isDark ? '#66FFFFFF' : '#66000000')
                  }
                  .width('100%')
                  .padding({ top: 60 })
                  .alignItems(HorizontalAlign.Center)
                } else {
                  ForEach(this.myDocs, (doc: UserDocument) => {
                    this.DocCard(doc, true)
                  })
                }
              } else {
                if (this.sharedDocs.length === 0) {
                  Column({ space: 8 }) {
                    Text('🔗')
                      .fontSize(40)
                    Text('还没有分享给你的文档')
                      .fontSize(15)
                      .fontColor(this.isDark ? '#99FFFFFF' : '#99000000')
                    Text('通过文档ID导入他人分享的文档')
                      .fontSize(12)
                      .fontColor(this.isDark ? '#66FFFFFF' : '#66000000')
                  }
                  .width('100%')
                  .padding({ top: 60 })
                  .alignItems(HorizontalAlign.Center)
                } else {
                  ForEach(this.sharedDocs, (doc: UserDocument) => {
                    this.DocCard(doc, false)
                  })
                }
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 40 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }

        // 底部导入对话框
        if (this.showImportDialog) {
          Column() {
            Column() {
              Text('导入共享文档')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
                .margin({ bottom: 12 })

              TextInput({ text: this.importDocId, placeholder: '输入文档ID' })
                .fontSize(14)
                .height(44)
                .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
                .placeholderColor(this.isDark ? '#66FFFFFF' : '#66000000')
                .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
                .borderRadius(12)
                .padding({ left: 16, right: 16 })
                .onChange((v: string) => { this.importDocId = v; })

              Row({ space: 12 }) {
                Button('取消')
                  .fontSize(14)
                  .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
                  .backgroundColor(this.isDark ? '#33FFFFFF' : '#0D000000')
                  .type(ButtonType.Capsule)
                  .height(40)
                  .layoutWeight(1)
                  .onClick(() => {
                    this.showImportDialog = false;
                    this.importDocId = '';
                  })

                Button('导入')
                  .fontSize(14)
                  .fontColor(Color.White)
                  .backgroundColor('#0A59F7')
                  .type(ButtonType.Capsule)
                  .height(40)
                  .layoutWeight(1)
                  .onClick(() => this.handleImport())
              }
              .width('100%')
              .margin({ top: 16 })
            }
            .width('85%')
            .padding(24)
            .borderRadius(24)
            .backgroundColor(this.isDark ? 'rgba(36,36,36,0.98)' : 'rgba(240,244,255,0.98)')
            .backdropBlur(80)
          }
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.4)')
          .justifyContent(FlexAlign.Center)
          .zIndex(20)
          .onClick(() => {
            this.showImportDialog = false;
            this.importDocId = '';
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.isDark ? '#000000' : '#F1F3F5')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 导航栏
      Row() {
        Row({ space: 8 }) {
          Text('云文档')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontFamily('HarmonyOS Sans')
            .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')

          Row() {
            Row()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(this.isCloudConnected ? '#00A854' : '#FAAD14')

            Text(this.isCloudConnected ? '云端' : '本地')
              .fontSize(11)
              .fontColor(this.isCloudConnected ? '#00A854' : '#FAAD14')
          }
          .padding({ left: 6, right: 8, top: 3, bottom: 3 })
          .borderRadius(8)
          .backgroundColor(this.isCloudConnected ? 'rgba(0,168,84,0.1)' : 'rgba(250,173,20,0.1)')
        }
        .layoutWeight(1)

        Row({ space: 12 }) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Text('⟳')
              .fontSize(20)
              .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
          }
          .width(44)
          .height(44)
          .backgroundColor(this.isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.05)')
          .backdropBlur(50)
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
          .onClick(() => {
            CloudDBService.forceCloudMode();
            this.loadDocuments();
          })

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Text('←')
              .fontSize(20)
              .fontColor(this.isDark ? '#E5FFFFFF' : '#E5000000')
              .fontWeight(FontWeight.Medium)
          }
          .width(44)
          .height(44)
          .backgroundColor(this.isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.05)')
          .backdropBlur(50)
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
          .onClick(() => router.back({ url: '' }))
        }
      }
      .width('92%')
      .padding({ left: 24, right: 24, top: 16, bottom: 16 })
      .margin({ top: 24 })
      .borderRadius(32)
      .backgroundColor(this.isDark ? 'rgba(0,0,0,0.4)' : 'rgba(241,243,245,0.5)')
      .backdropBlur(80)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .zIndex(10)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
