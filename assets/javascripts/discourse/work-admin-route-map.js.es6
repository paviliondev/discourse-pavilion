export default {
  resource: 'admin',
  map() {
    this.route('adminWork', { path: '/work', resetNamespace: true });
  }
};
