const BASE_URL = 'https://your-domain.com';

const request = (url, options = {}) => {
  return new Promise((resolve, reject) => {
    wx.request({
      url: `${BASE_URL}${url}`,
      ...options,
      success: res => resolve(res.data),
      fail: err => reject(err)
    });
  });
};

const api = {
  getRecords: (token) => request('/api/records', {
    method: 'GET',
    header: { Authorization: `Bearer ${token}` }
  }),
  
  mergeAndUpload: (data, token) => request('/api/merge-and-upload', {
    method: 'POST',
    header: { 
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    data
  }),
  
  mergeDownload: (data, token) => {
    return new Promise((resolve, reject) => {
      wx.downloadFile({
        url: `${BASE_URL}/api/merge`,
        header: { 
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        data: JSON.stringify(data),
        filePath: `${wx.env.USER_DATA_PATH}/merged.gpx`,
        success: res => resolve(res),
        fail: err => reject(err)
      });
    });
  },
  
  getRecordFile: (recordId, format, token) => {
    return new Promise((resolve, reject) => {
      wx.downloadFile({
        url: `${BASE_URL}/api/records/${recordId}/file?format=${format}`,
        header: { Authorization: `Bearer ${token}` },
        success: res => resolve(res),
        fail: err => reject(err)
      });
    });
  }
};

module.exports = api;
