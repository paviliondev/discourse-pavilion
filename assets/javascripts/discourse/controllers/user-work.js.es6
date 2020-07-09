import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import Controller from '@ember/controller';

export default Controller.extend({  
  actions: {
    save() {
      const props = [
        'earnings_target_month',
      ];
      const data = {};
      
      props.forEach(p => {
        data[p] = this.get(`model.${p}`);
      })
      
      this.set('saving', true);
      
      ajax('/work/update', {
        type: 'PUT',
        data
      }).then(result => {
        props.forEach(p => {
          if (result[p]) {
            this.set(`model.${p}`, result[p]);
          }
        });
      }).catch(popupAjaxError).finally(() => {
        this.set('saving', false);
      });
    }
  }
})