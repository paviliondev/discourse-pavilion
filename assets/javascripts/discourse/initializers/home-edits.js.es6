import { setDefaultHomepage } from "discourse/lib/utilities";
import { withPluginApi } from 'discourse/lib/plugin-api';
import { observes, default as computed } from 'ember-addons/ember-computed-decorators';

export default {
  name: 'home-edits',
  initialize(container) {
    const currentUser = container.lookup('current-user:main');
    const siteSettings = container.lookup('site-settings:main');
    if (!currentUser || !currentUser.homepage_id) setDefaultHomepage('home');

    withPluginApi('0.8.23', api => {
      api.modifyClass('model:group', {
        @observes('client_group')
        setClientGroupDefaults() {
          if (this.get('client_group')) {
            this.setProperties({
              mentionable_level: 3,
              messageable_level: 3,
              visibility_level: 2,
              members_visibility_level: 2,
              title: "Client",
              grant_trust_level: 3
            });
          }
        },

        asJSON() {
          let attrs = this._super();
          attrs['client_group'] = this.get('client_group');
          return attrs;
        }
      });

      api.addNavigationBarItem({
        name: "assigned",
        href: '/assigned',
        before: siteSettings.top_menu.split('|')[0],
        customFilter: function (category) {
          return currentUser && currentUser.staff && !category;
        }
      });
      
      api.addNavigationBarItem({
        name: "unassigned",
        href: '/unassigned',
        before: siteSettings.top_menu.split('|')[0],
        customFilter: function (category) {
          return currentUser && currentUser.staff && !category;
        }
      });

      api.modifyClass('controller:preferences/interface', {
        @computed()
        userSelectableHome() {
          let core = this._super();
          core.push(...[
            { name: "Home", value: 101 },
            { name: "Assigned", value: 102 }
          ]);
          return core;
        },

        homeChanged() {
          const homepageId = this.get("model.user_option.homepage_id");
          if (homepageId === 101) {
            setDefaultHomepage("home");
          } else if (homepageId === 102) {
            setDefaultHomepage("assigned");
          } else {
            this._super();
          }
        }
      });
    });
  }
};
