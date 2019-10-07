import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({  
  actions: {
    save() {
      const data = {
        earnings_target_month: this.get('model.earnings_target_month')
      }
      
      this.set('saving', true);
      
      ajax('/work/update', {
        type: 'PUT',
        data
      }).then(result => {
        if (result.earnings_target_month) {
          this.set('model.custom_fields.earnings_target_month', result.earnings_target_month)
        }
      }).catch(popupAjaxError).finally(() => {
        this.set('saving', false);
      });
    }
  }
})