<div class="copyright" >
  {% set current = date(Date.now(), "YYYY") %}
  &copy; {% if theme.since and theme.since != current %} {{ theme.since }} - {% endif %}
  <span itemprop="copyrightYear">{{ current }}</span>
  <span class="with-love">
    <i class="fa fa-{{ theme.authoricon }}"></i>
  </span>
  <span class="author" itemprop="copyrightHolder">{{ config.author }}</span>
</div>

{% if theme.copyright %}
<div class="powered-by">
  {{ __('footer.powered', '<a class="theme-link" href="https://hexo.io">Hexo</a>') }}
</div>

<div class="powered-by">
  {{ __('footer.theme') }} -
  <a class="theme-link" href="https://github.com/iissnan/hexo-theme-next">
    NexT.{{ theme.scheme }}
  </a>
</div>
{% endif %}

{% if config.beian.enable %}
<div class="powered-by">
  <a href="{{ config.beian.link }}" target="_blank"><img src="/res/beian.png" style="float:left;"/>{{ config.beian.no }}</a>
</div>
{% endif %}

{% if config.miitbeian.enable %}
<div class="theme-info">
  <a href="{{ config.miitbeian.link }}" target="_blank">{{ config.miitbeian.no }}</a>
</div>
{% endif %}
