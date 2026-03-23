const api = require('../../utils/api');

Page({
  data: {
    loggedIn: false,
    userName: '',
    records: [],
    selectedCount: 0,
    loading: false,
    merging: false,
    mergeResult: null,
    token: ''
  },

  onLoad() {
    const token = wx.getStorageSync('access_token');
    const userName = wx.getStorageSync('user_name') || '用户';
    if (token) {
      this.setData({ loggedIn: true, token, userName });
      this.loadRecords();
    }
  },

  doLogin() {
    const app = getApp();
    const authUrl = `${app.globalData.baseUrl}/auth/login`;
    
    // 使用 web-view 跳转行者授权
    wx.setStorageSync('auth_url', authUrl);
    
    // 方案: 复制链接让用户在外部浏览器授权
    wx.setClipboardData({
      data: authUrl,
      success: () => {
        wx.showModal({
          title: '授权提示',
          content: '链接已复制，请在浏览器中打开完成授权。授权后回到此页面。',
          confirmText: '已授权',
          cancelText: '取消',
          success: (res) => {
            if (res.confirm) {
              // 用户确认已授权，刷新状态
              wx.showModal({
                title: '输入Token',
                content: '请在浏览器授权后，将获得的access_token粘贴到输入框',
                editable: true,
                placeholderText: '粘贴access_token',
                success: (r) => {
                  if (r.confirm && r.content) {
                    wx.setStorageSync('access_token', r.content);
                    this.setData({ loggedIn: true, token: r.content, userName: '用户' });
                    this.loadRecords();
                  }
                }
              });
            }
          }
        });
      }
    });
  },

  doLogout() {
    wx.removeStorageSync('access_token');
    wx.removeStorageSync('user_name');
    this.setData({ loggedIn: false, token: '', records: [], mergeResult: null });
  },

  async loadRecords() {
    this.setData({ loading: true });
    try {
      const res = await api.getRecords(this.data.token);
      const records = (res.records || []).map(r => ({
        ...r,
        selected: false,
        date: r.start_time ? r.start_time.split('T')[0] : (r.date || ''),
        distance: r.distance ? (r.distance / 1000).toFixed(1) : '0',
        duration: r.duration ? this.formatDuration(r.duration) : '00:00:00',
      }));
      this.setData({ records, loading: false });
    } catch (e) {
      this.setData({ loading: false });
      wx.showToast({ title: '加载失败', icon: 'error' });
    }
  },

  formatDuration(seconds) {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  },

  toggleRecord(e) {
    const id = e.currentTarget.dataset.id;
    const records = this.data.records.map(r => {
      if (r.id == id) r.selected = !r.selected;
      return r;
    });
    const selectedCount = records.filter(r => r.selected).length;
    this.setData({ records, selectedCount });
  },

  async doMerge() {
    const ids = this.data.records.filter(r => r.selected).map(r => String(r.id));
    this.setData({ merging: true });
    
    try {
      const res = await api.mergeAndUpload({ record_ids: ids, format: 'gpx' }, this.data.token);
      this.setData({ mergeResult: res, merging: false });
      
      if (res.success) {
        wx.showToast({ title: '合并成功！', icon: 'success' });
      } else {
        wx.showToast({ title: '合并成功，上传失败', icon: 'none' });
      }
    } catch (e) {
      this.setData({ merging: false });
      wx.showToast({ title: '合并失败: ' + (e.message || '未知错误'), icon: 'error' });
    }
  },

  async doDownload() {
    const ids = this.data.records.filter(r => r.selected).map(r => String(r.id));
    try {
      const res = await api.mergeDownload({ record_ids: ids, format: 'gpx' }, this.data.token);
      wx.openDocument({
        filePath: res.filePath,
        fileType: 'gpx',
        success: () => wx.showToast({ title: '文件已打开' }),
        fail: () => wx.showToast({ title: '下载成功', icon: 'success' })
      });
    } catch (e) {
      wx.showToast({ title: '下载失败', icon: 'error' });
    }
  },

  resetMerge() {
    const records = this.data.records.map(r => ({ ...r, selected: false }));
    this.setData({ records, selectedCount: 0, mergeResult: null });
  }
});
